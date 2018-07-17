pragma solidity ^0.4.21;

import "./SafeMath.sol";

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

interface token {
    function balanceOf(address _account) external view returns (uint256 balance);
    function transfer(address receiver, uint256 amount) external;
}

/**
 * Secured Deposit(보호예수) Smart Contract
 * Written by Shin HyunJae
 * version 2
 */
contract SafeDeposit is Ownable {
    using SafeMath for uint256;
    
    uint256 public endOfPeriod;
    mapping(address => uint256) public holdingBalanceOf;
    token public tokenReward;
    
    event Withdraw(address recipient, uint256 amount);
    
    /**
     * Constructor function
     *
     * Setup the owner
     */
    constructor(
        address addressOfTokenUsedAsReward
    ) public {
        tokenReward = token(addressOfTokenUsedAsReward);
        endOfPeriod = (24 * 60 * 365 * 1 minutes) + now;        // 1 year
        // endOfPeriod = (60 * 1 minutes) + now;                   // 1 hour
        
        // Secured address list
        uint256 decimals = 18;
        holdingBalanceOf[0x1aa6098f8a2d49e2Ba920cd2A7221F5c3F0B235C] = uint256(2500000).mul(10 ** decimals);    // 이왕재
        holdingBalanceOf[0x86Cbd59e426a82cc4CE40d51EC3c11d4168Cf344] = uint256(1000000).mul(10 ** decimals);    // 신현재
        holdingBalanceOf[0x767A67c9B24290d725988F71433f65e0DDdDC92d] = uint256(1000000).mul(10 ** decimals);    // 이지현
        holdingBalanceOf[0x64EFa6115070eF1a98Caa3bD6B1EC90ebB560A9e] = uint256(1000000).mul(10 ** decimals);    // 안중혁
        holdingBalanceOf[0x7E0DD43868cD7e808a7582F121cFcef53c5df840] = uint256(1000000).mul(10 ** decimals);    // 이윤수
        holdingBalanceOf[0xcEfb95ab1eef1C5224Bb67CF4b9587F29b95DcD2] = uint256(1000000).mul(10 ** decimals);    // 곽헌
        holdingBalanceOf[0x950F5Ec63EE946456BC1dB7BA919e1B27Ac73ddc] = uint256(1000000).mul(10 ** decimals);    // 전영대
        holdingBalanceOf[0x19F8D8Fd9d8a6af29181a770c5EcB5695aAA3800] = uint256(1000000).mul(10 ** decimals);    // 김종현
        holdingBalanceOf[0x6def614567570e070cf6a4f408411721db9225d4] = uint256(25000000).mul(10 ** decimals);   // 네모랩
    }

    modifier afterDeadline() { require(now >= endOfPeriod); _; }

    /**
     * Fallback function
     *
     * The function without name is the default function that is called whenever anyone sends funds to a contract
     */
    function () payable external afterDeadline {
        require(holdingBalanceOf[msg.sender] > 0);
        require(tokenReward.balanceOf(this) >= holdingBalanceOf[msg.sender]);
        require(msg.value == 0);

        uint256 amount = holdingBalanceOf[msg.sender];
        tokenReward.transfer(msg.sender, amount);
        holdingBalanceOf[msg.sender] = 0;
        emit Withdraw(msg.sender, amount);
    }

    /**
     * Get remaining time
     * 
     * Get remaining time in minutes to deadline of token sale
     */
    function getRemainingTime() external view returns (uint256 remainingTime) {
        remainingTime = (endOfPeriod > now && endOfPeriod - now >= 1 minutes) ? (endOfPeriod - now) / 1 minutes : 0;
        return remainingTime;
    }

    /**
     * Withdraw the remaining tokens
     *
     * @notice Withdraw the remaining tokens from this contract to _recipient.
     */
    function withdrawRemainingTokens(address _recipient) onlyOwner public {
        uint256 tokenBalance = tokenReward.balanceOf(this);
        if (tokenBalance > 0) tokenReward.transfer(_recipient, tokenBalance);
    }

    /**
     * Withdraw the remaining ether
     *
     * @notice Withdraw the remaining ether from this contract to _recipient.
     */
    // function withdrawRemainingEther(address _recipient) onlyOwner public {
    //     uint256 remainingBalance = address(this).balance;
    //     require(remainingBalance > 0);
    //     _recipient.transfer(remainingBalance);
    // }

    /**
     * Destroy this contract
     *
     * @notice Remove this contract from the system irreversibly and send remain funds to owner account
     * @notice 정식 배포시 삭제예정
     */
    function destroy() external onlyOwner {
        destroyAndSend(owner);
    }
    
    /**
     * Destroy this contract
     *
     * @notice Remove this contract from the system irreversibly and send remain funds to _recipient account
     * @notice 정식 배포시 삭제예정
     * 
     * @param _recipient Address to receive the funds
     */
    function destroyAndSend(address _recipient) public onlyOwner {
        uint256 tokenBalance = tokenReward.balanceOf(this);
        require(tokenBalance == 0); // Check if this contract have remaining tokens
        selfdestruct(_recipient);
    }

}