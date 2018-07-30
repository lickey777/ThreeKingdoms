pragma solidity ^0.4.24;

contract ThreeKingdomsTest {

    uint constant kingdomNum = 3;  // number of kingdoms

    struct KingdomInfo {
        uint balance;  // store balance for each kingdom
        mapping(address => uint) votes;  // store votes for each kingdom
        address[] voters;  // store voters for each kingdom
    }
    KingdomInfo[kingdomNum] data;  // main data structure

    // the person who can finalize the game
    address owner;
    // the block number end up with
    uint endBlockNum;
    // max block number since last deposit, approximate 144*200/3600=8 hours
    uint constant maxBlockNum = 30;
    // min vote value, 0.1 QTUM
    uint constant qtumToken = 1e8;
    uint constant minVoteValue = qtumToken / 10;
    // percentage decimal
    uint constant ratioDecimal = 10000;
    // percentage of value reward voters
    uint constant ratio = 8500;

    modifier validKingdomIndex(uint8 kingdomIndex) {
        require(kingdomIndex < kingdomNum, "invalid kingdomIndex");
        _;
    }

    /**
    * init owner, data and endBlockNum
    */
    constructor() public {
        owner = msg.sender;

        for(uint i = 0; i < kingdomNum; i++) {
            data[i].balance = 0;
        }

        endBlockNum = block.number + maxBlockNum;
    }
    function getOwner() external view returns(address) {
        return owner;
    }

    /**
    * return price per vote in ratioDecimal,
    * that is, the return value / ratioDecimal is the actual price
    * init with 0.01 
    * and when value rise to 1000 the price rise to 1.01
    * should subtract the value send this time when get value
    */
    function getVotePrice(uint currentSend) public view returns(uint) {
        uint value = address(this).balance - currentSend;  // sub the value send currently
        uint token = value / qtumToken;
        return ratioDecimal / 100 + ratioDecimal * token / 10000;
    }
    /**
    * vote token for your kingdom
    */
    event Vote(
        address indexed _from,
        uint8 indexed _index,
        uint _value
    );
    function vote(uint8 kingdomIndex) external payable validKingdomIndex(kingdomIndex) 
            returns(uint) {
        require(msg.value >= minVoteValue, "vote value is lower than threshold");
        require(!isGameOver(), "game is over");

        // append address to votes if hasn't voted before
        if (data[kingdomIndex].votes[msg.sender] == 0) {
            data[kingdomIndex].voters.push(msg.sender);
        }

        // transfer value to votes
        uint votes = (msg.value * ratioDecimal) / getVotePrice(msg.value);
        data[kingdomIndex].votes[msg.sender] += votes;
        data[kingdomIndex].balance += votes;

        emit Vote(msg.sender, kingdomIndex, msg.value);

        // update endBlockNum
        endBlockNum = block.number + maxBlockNum;
    }

    /**
    * detect if the game is over
    * if current block number is large than endBlockNum
    * and there is no deuce, the game is over.
    * only when res == true, other return params take effect
    */
    function getBlockLeft() public view returns(int) {
        if (endBlockNum < block.number) {
            return int(-(block.number - endBlockNum));
        }
        return int(endBlockNum - block.number);
    }
    function isGameOver() public view returns(bool res) {  // only return a bool
        int blockLeft;
        uint8 resType;
        uint8[kingdomNum] memory indexSort; 
        uint[kingdomNum] memory balanceSort;
        (res, blockLeft, resType, indexSort, balanceSort) = checkGameOver();
        return;
    }
    function checkGameOver() public view returns(  // return bool and other status params
            bool res,
            int blockLeft,
            uint8 resType, 
            uint8[kingdomNum] indexSort, 
            uint[kingdomNum] balanceSort) {
        blockLeft = getBlockLeft();

        // cost a lot of gas when finalize and deuce
        if (blockLeft < 0) {
            (resType, indexSort, balanceSort) = getGameResult();

            if (resType == 2 || resType == 3) {
                res = true;
                return;
            } 
        }

        res = false;
        return;
    }
    /**
    * get the status of the game, there are 4 type of status
    * 
    * uint8
    * 0 means a = b = c
    * 1 means a = b+c;
    * 2 means a > b+c;
    * 3 means a < b+c;
    * uint[kingdomNum]
    * kingdom index sort by balance, from high to low
    */
    function getGameResult() public view returns(
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
    * sort three kingdoms by balance, from high to low, a hack way
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
    * finalize the game, only owner can call it
    * will call checkGameOver(), reward() and withdraw()
    */
    function finalize() external {
        require(owner == msg.sender, "only owner can finalize the game");

        bool res;
        int blockLeft;
        uint8 resType;
        uint8[kingdomNum] memory indexSort;
        uint[kingdomNum] memory balanceSort;
        (res, blockLeft, resType, indexSort, balanceSort) = checkGameOver();

        require(res, "the game is not over");  // game should be over

        // get value reward to voters
        uint rewardValue = getRewardValue();

        // reward voters according to different end status
        if (resType == 2) {
            reward(indexSort[0], balanceSort[0], rewardValue);
        } else {
            uint totalBalance = balanceSort[1] + balanceSort[2];
            reward(indexSort[1], totalBalance, rewardValue);
            reward(indexSort[2], totalBalance, rewardValue);
        }

        // withdraw left money to owner
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
    event Reward(
        address indexed _to,
        uint _value
    );
    function reward(uint8 kingdomIndex, uint totalBalance, uint rewardValue) 
            private validKingdomIndex(kingdomIndex) {
        uint voterLength = data[kingdomIndex].voters.length;
        for (uint i = 0; i < voterLength; i++) {
            address voterAddress = data[kingdomIndex].voters[i];
            uint voterBlance = data[kingdomIndex].votes[voterAddress];
            uint voterAmount = getRewardAmount(voterBlance, totalBalance, rewardValue);
            reward(voterAddress, voterAmount);
        }
    }
    function reward(address addr, uint amount) private {
        addr.transfer(amount);
        emit Reward(addr, amount);
    }
    function getRewardAmount(uint balance, uint totalBalance, uint rewardValue) public pure returns(uint) {
        return (rewardValue * balance) / totalBalance;
    }

    /**
    * withdraw left token to reward the owner
    */
    function withdraw() private {
        uint amount = address(this).balance;
        owner.transfer(amount);
    }

    function getBalance(uint8 kingdomIndex) public view validKingdomIndex(kingdomIndex) 
            returns(uint) {
        return data[kingdomIndex].balance;
    }

    function getValue() public view returns(uint) {
        return address(this).balance;
    }

    function getVoters(uint8 kingdomIndex) public view validKingdomIndex(kingdomIndex) 
            returns(address[]) {
        return data[kingdomIndex].voters;
    }

    function getVote(uint8 kingdomIndex, address addr) public view validKingdomIndex(kingdomIndex) 
            returns(uint){
        return data[kingdomIndex].votes[addr];
    }

    function getVotes(uint8 kingdomIndex) public view validKingdomIndex(kingdomIndex) 
            returns(uint[]) {
        uint voterLength = data[kingdomIndex].voters.length;
        uint[] memory votes = new uint[](voterLength);
        
        for (uint i = 0; i < voterLength; i++) {
            address addr = data[kingdomIndex].voters[i];
            uint balance = data[kingdomIndex].votes[addr];
            votes[i] = balance;
        }

        return votes;
    }

    function getVotersVotesRewards(uint8 kingdomIndex) public view validKingdomIndex(kingdomIndex) 
            returns(address[] voters, uint[] votes, uint[] rewards) {
        voters = getVoters(kingdomIndex);
        votes = getVotes(kingdomIndex);
        uint length = voters.length;
        rewards = new uint[](length);
        
        uint8 resType;
        uint8[kingdomNum] memory indexSort;
        uint[kingdomNum] memory balanceSort;
        (resType, indexSort, balanceSort) = getGameResult();

        // deuce, no reward
        if (resType == 0 || resType == 1) {
            return;
        }

        uint totalBalance;
        uint reward;
        uint rewardValue = getRewardValue();
        if (resType == 2) {
            // loser
            if (kingdomIndex != indexSort[0]) {
                return;
            }

            totalBalance = balanceSort[0];
            for (uint i = 0; i < length; i++) {
                reward = getRewardAmount(
                    votes[i], 
                    totalBalance, 
                    rewardValue);
                rewards[i] = reward;
            }
            return;
        } else {
            // loser
            if (kingdomIndex == indexSort[0]) {
                return;
            }

            totalBalance = balanceSort[1] + balanceSort[2];
            for (uint j = 0; j < length; j++) {
                reward = getRewardAmount(
                    votes[j], 
                    totalBalance, 
                    rewardValue);
                rewards[j] = reward;
            }
            return;
        }
    }
}