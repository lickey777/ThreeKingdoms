pragma solidity ^0.4.24;

contract ThreeKingdoms {

    uint constant kingdomNum = 3;

    struct KingdomInfo {
        uint balance;  // store balance for each kingdom
        mapping(address => uint) votes;  // store votes for each kingdom
        address[] voters;  // store voters for each kingdom
    }

    KingdomInfo[kingdomNum] data;

    // the person who can finalize the game
    address owner;
    // the block number end up with
    uint endBlockNum;
    // max block number since last deposit, approximate 144*200/3600=8 hours
    uint constant maxBlockNum = 200;
    // min vote value, 0.1 QTUM
    uint constant minVoteValue = 100000000;
    // percentage of value reward voters
    uint constant ratio = 90;
    uint constant ratioDecimal = 100;

    /**
    * init owner, data  and endBlockNum
    */
    constructor() public {
        owner = msg.sender;

        for(uint i = 0; i < kingdomNum; i++) {
            data[i].balance = 0;
        }

        endBlockNum = block.number + maxBlockNum;
    }

    /**
    * vote token for your kingdom
    */
    function vote(uint8 kingdomIndex) external payable returns(uint) {
        require(kingdomIndex < kingdomNum, "wrong input kingdomIndex");
        require(msg.value >= minVoteValue, "vote value is lower than threshold");
        require(!isGameOver(), "game is over");

        if (data[kingdomIndex].votes[msg.sender] != 0) {
            data[kingdomIndex].voters.push(msg.sender);
        }
        data[kingdomIndex].votes[msg.sender] += msg.value;
        data[kingdomIndex].balance += msg.value;

        // update endBlockNum
        endBlockNum = block.number + maxBlockNum;
    }

    /**
    * detect if the game is over
    * if current block number is large than endBlockNum
    * and there is no deuce, the game is over.
    * only when res == true, other return params take effect
    */
    function isGameOver() public view returns(bool res) {
        uint8 resType;
        uint8[kingdomNum] memory indexSort; 
        uint[kingdomNum] memory balanceSort;
        (res, resType, indexSort, balanceSort) = checkGameOver();
        return;
    }
    function checkGameOver() public view returns(
            bool res,
            uint8 resType, 
            uint8[kingdomNum] indexSort, 
            uint[kingdomNum] balanceSort) {

        if (block.number > endBlockNum) {
            (resType, indexSort, balanceSort) = gameResult();

            if (resType == 2 || resType == 3) {
                res = true;
                return;
            } 
        }

        res = false;
        return;
    }

    /**
    * game result
    * 
    * uint8
    * 0 means a = b = c
    * 1 means a = b+c;
    * 2 means a > b+c;
    * 3 means a < b+c;
    * uint[kingdomNum]
    * kingdom index sort by balance, from high to low
    */
    function gameResult() private view returns(
            uint8 resType, 
            uint8[kingdomNum] indexSort, 
            uint[kingdomNum] balanceSort) {

        (indexSort, balanceSort) = sortThree();

        if (balanceSort[0] == balanceSort[1] &&
                balanceSort[1] == balanceSort[2]) {
            resType = 0;
            return;
        }

        uint balanceCombine = balanceSort[1] + balanceSort[2];
        if (balanceSort[0] == balanceCombine) {
            resType = 1;
            return;
        }

        if (balanceSort[0] > balanceCombine) {
            resType = 2;
            return;
        }

        resType = 3;
        return;
    }

    /**
    * sort three kingdoms by balance, from high to low
    */
    function sortThree() private view returns(uint8[kingdomNum], uint[kingdomNum]) {
        uint balance0 = data[0].balance;
        uint balance1 = data[1].balance;
        uint balance2 = data[2].balance;

        if (balance0 >= balance1) {
            if (balance1 >= balance2) {
                return ([0, 1, 2], [balance0, balance1, balance2]);
            } else {
                if (balance0 >= balance2) {
                    return ([0, 2, 1], [balance0, balance2, balance1]);
                } else {
                    return ([2, 0, 1], [balance2, balance0, balance1]);
                }
            }
        } else {
            if (balance0 >= balance2) {
                return ([1, 0, 2], [balance1, balance0, balance2]);
            } else {
                if (balance1 >= balance2) {
                    return ([1, 2, 0], [balance1, balance2, balance0]);
                } else {
                    return ([2, 1, 0], [balance2, balance1, balance0]);
                }
            }
        }
    }

    /**
    * finalize the game
    * will call checkGameOver(), reward() and withdraw()
    */
    function finalize() external {
        require(owner == msg.sender, "only owner can finalize the game");

        (bool res,
        uint8 resType, 
        uint8[kingdomNum] memory indexSort,
        uint[kingdomNum] memory balanceSort) = checkGameOver();

        require(res, "the game is not over");

        // get reward value
        uint rewardValue = getRewardValue();

        // reward voters
        if (resType == 2) {
            reward(indexSort[0], balanceSort[0], rewardValue);
        } else {
            uint totalBalance = balanceSort[1] + balanceSort[2];
            reward(indexSort[1], totalBalance, rewardValue);
            reward(indexSort[2], totalBalance, rewardValue);
        }

        // developer withdraw
        withdraw();
    }

    /**
    * get value to reward voters
    */
    function getRewardValue() public view returns(uint) {
        uint total = address(this).balance;
        return (total * ratio) / ratioDecimal;
    }

    /**
    * reward a kingdom or an address
    */
    function reward(uint8 kingdomIndex, uint totalBalance, uint rewardValue) private {
        uint voterLength = data[kingdomIndex].voters.length;
        for (uint i = 0; i < voterLength; i++) {
            address voterAddress = data[kingdomIndex].voters[i];
            uint voterBlance = data[kingdomIndex].votes[voterAddress];
            reward(voterAddress, voterBlance, totalBalance, rewardValue);
        }
    }
    function reward(address addr, uint balance, uint totalBalance, uint rewardValue) private {
        uint amount = (rewardValue * balance) / totalBalance;
        addr.transfer(amount);
    }

    /**
    * withdraw left token to reward the owner
    */
    function withdraw() private {
        uint amount = address(this).balance;
        owner.transfer(amount);
    }

    function getBalance(uint8 kingdomIndex) public view returns(uint) {
        require(kingdomIndex < kingdomNum, "wrong input kingdomIndex");
        return data[kingdomIndex].balance;
    }

    function getValue() public view returns(uint) {
        return address(this).balance;
    }

    function getEndBlockNum() public view returns(uint){
        return endBlockNum;
    }

    function getVoters(uint8 kingdomIndex) public view returns(address[]){
        require(kingdomIndex < kingdomNum, "wrong input kingdomIndex");
        return data[kingdomIndex].voters;
    }

    function getVotes(uint8 kingdomIndex, address addr) public view returns(uint){
        require(kingdomIndex < kingdomNum, "wrong input kingdomIndex");
        return data[kingdomIndex].votes[addr];
    }
}