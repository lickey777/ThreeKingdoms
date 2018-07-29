pragma solidity ^0.4.24;

contract theThreeKingdoms {

    enum KingdomName {
        Wei,
        Shu,
        Wu
    }
    uint constant KingdomNum = 3;

    struct KingdomInfo {
        mapping(address => uint) votes;  // store votes for each kingdom
        address[] voters;  // store voters for each kingdom
        uint[] votersBalance;
        uint balance;  // store balance for each kingdom
    }

    KingdomInfo[KingdomNum] data;

    // the person who can finalize the game
    address owner;
    // the game end timestamp
    uint endtime;

    uint constant ratio = 9000;
    
    uint ratioDecimal = 10000;
    
    uint decimal=100000000;

    uint constant minValue = 100000000;

    /* function setOwner(){
        owner = msg.sender;
    }  */

    /*
        @description: Only owner can call this function
    */
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
/*
    function startGame() public onlyOwner{
        endtime = block.number + 10000;
    }
*/
    /*
        @description: detect if the game is over
    */
    modifier gameOver {
        _;
    }

    /*
        @description: init data, owner and endtime
    */
    function theThreeKingdoms() public {
        owner = msg.sender;
        for(uint i = 0; i < KingdomNum; i++)
            data[i].balance = 0;
        endtime = block.number + 10000;
    }

    /*
        @description: vote token for your kingdom
    */
    function votebalance(uint temp,address tempaddr,uint value) private {
        for(uint i = 0; i < data[temp].voters.length; i++){
            if(data[temp].voters[i] == tempaddr)
            data[temp].votersBalance[i] += value;
        }
    }
    
    function vote(KingdomName kingdom) external payable returns(string,bool){
        if(msg.value < minValue)
        return ("Please vote more qtum!",false);
        else{
          uint index = uint(kingdom);
          if (data[index].votes[msg.sender] != 0){
            data[index].votes[msg.sender] += msg.value;
            data[index].balance += msg.value;
            votebalance(index,msg.sender,msg.value);
          }
          else{
            data[index].votes[msg.sender] += msg.value;
            data[index].voters.push(msg.sender);
            data[index].balance += msg.value;
            data[index].votersBalance.push(msg.value);
          }
          return ("fight for your kingdom!",true);
        }


    }

    /*
        @description: finalize the game
        will call reward() and withdraw()
    */
    function finalize() external {
        withdraw();
    }

        /*
        @description: distribute rewards to people who win the game
    */
    function reward(address voterAddress) public returns (uint[]){
        uint[] values;
        uint total = 0;
        uint balance = 0;
        
        
        for (uint i = 0; i < KingdomNum; i++) {
            values.push(data[i].votes[voterAddress]);
            balance = data[i].balance;
            total += balance;
        }


        for (i = 0; i < KingdomNum; i++) {
            if (values[i] != 0) {
                uint rewardByKing = safeMul(total, values[i]);
                values[i] = safeMul((rewardByKing / values[i]),ratio) / ratioDecimal;
            } else {
                values[i] = 0;
            }
        }

        return values;
    }

    /*
        @description: withdraw left token to reward the developer
    */
    function withdraw() private onlyOwner {
        assert(block.number >= endtime);
        assert(!deuceEqualityAsIndividual());
        uint8 direction;
        uint max;
        uint maxIndex;
        uint total;
        (direction, max, maxIndex, total) = deuceEqualityAsAlliance();
        if (direction == 0) {
            return;
        }

        uint i;

        uint reward = safeMul(total, ratio);


        if (direction == 1) {
            reward = safeMul(reward / max , ratio) / ratioDecimal;
            address[] vs = data[maxIndex].voters;
            for (uint j = 0; j < vs.length; j++) {
                address voter = vs[j];
                uint amount = data[maxIndex].votes[voter];
                uint rewardByVoter = safeMul(amount, reward);
                voter.send(rewardByVoter);
            }
        } else {
            reward = safeMul(reward / (safeSub(total , max)) , ratio) / ratioDecimal;
            for (i = 0; i < KingdomNum; i++) {
                if (i != maxIndex) {
                    vs = data[i].voters;

                    for(j = 0; j < vs.length; j ++) {
                        voter = vs[j];
                        amount = data[i].votes[voter];
                        rewardByVoter = safeMul(amount, reward);
                        voter.send(rewardByVoter);
                    }
                }
            }
        }

    }

    // 多方势力值相等
    function deuceEquality() private returns (bool) {
        uint amount = data[0].balance;
        for (uint i = 1; i < KingdomNum; i++) {
            if (amount != data[i].balance) {
                return false;
            }
        }
        return true;

    }

    function deuceEqualityAsIndividual() private returns (bool) {
        uint amount = data[0].balance;
        for (uint i = 1; i < KingdomNum; i++) {
            if (amount != data[i].balance) {
                return false;
            }
        }
        return true;

    }
    //一方等于双方的和
    // 0 means a = b+c;
    // 1 means a > b+c;
    // 2 means a < b+c;
    function deuceEqualityAsAlliance() private returns (uint8, uint, uint, uint) {
        uint[] kingsAmount;
        uint total = 0;
        uint max = data[0].balance;
        uint maxIndex = 0;
        for (uint i = 0; i < KingdomNum; i++) {
            kingsAmount[i] = data[i].balance;
            total += kingsAmount[i];
            if (max < kingsAmount[i]) {
                max = kingsAmount[i];
                maxIndex = i;
            }
        }

        uint value = safeSub(total, max);
        if (value == max) {
            return (0, max, maxIndex, total);
        } else if (value < max) {
            return (1, max, maxIndex, total);
        } else if (value > max) {
            return (2, max, maxIndex, total);
        }

    }

    // Overflow protected math functions

    /**
        @dev returns the sum of _x and _y, asserts if the calculation overflows

        @param _x   value 1
        @param _y   value 2

        @return sum
    */
    function safeAdd(uint _x, uint _y) internal pure returns (uint) {
        uint z = _x + _y;
        assert(z >= _x);
        return z;
    }

    /**
        @dev returns the difference of _x minus _y, asserts if the subtraction results in a negative number

        @param _x   minuend
        @param _y   subtrahend

        @return difference
    */
    function safeSub(uint _x, uint _y) internal pure returns (uint) {
        assert(_x >= _y);
        return _x - _y;
    }

    /**
        @dev returns the product of multiplying _x by _y, asserts if the calculation overflows

        @param _x   factor 1
        @param _y   factor 2

        @return product
    */
    function safeMul(uint _x, uint _y) internal pure returns (uint) {
        uint z = _x * _y;
        assert(_x == 0 || z / _x == _y);
        return z;
    }
    //  返回指定 kingdom 的 balance；
    function showBalance(KingdomName kingdom) public view returns(uint){
      // uint balanceOfKingdom = data[index].balance;
      // return balanceOfKingdom;
      uint index = uint(kingdom);
      return data[index].balance;
    }

    //  返回总的 balance
    function showTotalBalance() public view returns(uint){
      uint totalBalance = 0;
      for(uint i = 0; i < KingdomNum; i++){
        totalBalance += data[i].balance;
      }
      return totalBalance;
    }

    //  指定地址 address 和 kingdom 的 index，返回其收益；
    function showReword(KingdomName kingdom, address addr) public view returns(uint){
      uint index = uint(kingdom);
      uint[] memory rewardData = reward(addr);
      return rewardData[index];
    }

    //  指定 kingdom 的 index，返回其所有的 vote 数据；
    function getVoteData(KingdomName kingdom) public view returns(address[],uint[]){
      uint index = uint(kingdom);
      return (data[index].voters,data[index].votersBalance);
    }
    

    //  返回游戏结束的时间，以区块数为计量标准；
    function showEndtime() public view returns(uint){
      return (endtime - block.number);
    }


}
