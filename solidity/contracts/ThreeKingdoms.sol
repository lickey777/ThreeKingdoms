pragma solidity ^0.4.7;

contract ThreeKingdoms {

    enum KingdomName {
        Wei,
        Shu,
        Wu
    }
    uint constant KingdomNum = 3;
    
    struct KingdomInfo {
        mapping(address => uint) votes;  // store votes for each kingdom
        address[] voters;  // store voters for each kingdom
        uint balance;  // store balance for each kingdom
    }
    KingdomInfo[KingdomNum] data;

    // the person who can finalize the game
    address owner;
    // the game end timestamp
    uint endtime;
    
    /*
        @description: Only owner can call this function
    */
    modifier onlyOwner {
        _;
    }
    
    /*
        @description: detect if the game is over
    */
    modifier gameOver {
        _;
    }
    
    /*
        @description: init data, owner and endtime
    */
    constructor() public {
    }
    
    /*
        @description: vote token for your kingdom
    */
    function vote(KingdomName kingdom) external payable {
        uint index = uint(kingdom);
    }
    
    /*
        @description: finalize the game
        will call reward() and withdraw()
    */
    function finalize() external {
    }
    
    /*
        @description: distribute rewards to people who win the game
    */
    function reward() private {
    }
    
    /*
        @description: withdraw left token to reward the developer
    */
    function withdraw() private {
    }
}