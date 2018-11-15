pragma solidity ^0.4.21;

contract Ownable {
    address internal owner;

    /* you have to use this contract to be inherited because it is internal.*/
    constructor() internal {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner public {
        owner = newOwner;
    }

}

contract Pausable is Ownable {
    event Pause();
    event Unpause();

    bool internal paused;

    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    modifier whenPaused() {
        require(paused);
        _;
    }

    modifier noReentrancy() {
        require(!paused);
        paused = true;
        _;
        paused = false;
    }

    /* When you discover your smart contract is under attack, you can buy time to upgrade the contract by
       immediately pausing the contract.
     */
    function pause() public onlyOwner whenNotPaused {
        paused = true;
        emit Pause();
    }

    function unpause() public onlyOwner whenPaused {
        paused = false;
        emit Unpause();
    }
}


interface token {
    //function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    //function isOwnerPayable(uint256 payment) external view returns (bool success);
    function transfer(address _to, uint256 _value) public noReentrancy returns (bool success);
    function balanceOf(address _account) external view returns (uint256 balance);
}

contract TokenExchanger is Pausable {
    token public tokenReward;
    address owner;
    uint256 public checkValue = 1;

    constructor(
        address addressOfTokenUsedAsReward // nomo token contract
    ) public {
        tokenReward = token(addressOfTokenUsedAsReward);
    }

    function exchangeEtherToToken(uint256 exchangeRate) payable external returns (bool success){
        uint256 tokenPayment;
        require(msg.value > 0);
        require(exchangeRate != 0);

        tokenPayment = msg.value * exchangeRate;
        require(tokenReward.balanceOf(address(this)) >= tokenPayment);
        require(tokenReward.transfer(msg.sender, tokenPayment));
        success = true;
        return success;
    }


    function exchangeTokenToEther(uint256 amountOfToken, uint256 exchangeRate) external returns (bool success){

    }

}
