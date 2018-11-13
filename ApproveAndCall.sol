pragma solidity ^0.4.21;

interface token {
    function balanceOf(address _account) external view returns (uint256 balance);
    function transfer(address receiver, uint256 amount) external;
    function approveAndCall(address _spender, uint256 _value, bytes _extraData) external returns (bool success);
}

contract ApproveAndCall {
    token public tokenReward;
    uint256 public checkValue = 1;
    
    event ReceiveApproval(address sender, uint256 amount, address addressOfToken, bytes extraData);
    
    constructor(
        address addressOfTokenUsedAsReward
    ) public {
        tokenReward = token(addressOfTokenUsedAsReward);
    }

    function receiveApproval(address _sender, uint256 _amount, address _addressOfToken, bytes _extraData) external {
        emit ReceiveApproval(_sender, _amount, _addressOfToken, _extraData);
        checkValue += 1;
    }

}