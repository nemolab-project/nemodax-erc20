pragma solidity ^0.4.21;

interface token {
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function isOwnerPayable(uint256 payment) external view returns (bool success);
}

contract TokenExchanger {
    token public tokenReward;
    address owner;
    uint256 public checkValue = 1;

    event ReceiveApproval(address sender, uint256 amount, address addressOfToken, bytes extraData);

    constructor(
        address addressOfTokenUsedAsReward
    ) public {
        tokenReward = token(addressOfTokenUsedAsReward);
    }

    function receiveApproval(address _sender, uint256 _amount, address _addressOfToken, address _addressOfOwner, bytes _extraData) external {
        owner = _addressOfOwner;
        emit ReceiveApproval(_sender, _amount, _addressOfToken, _extraData);
        checkValue += 1;
    }

    function exchangeToken(uint256 exchangeRate) payable external returns (bool success){
        uint256 payment;
        require(msg.value > 0);
        require(exchangeRate != 0);

        require(address(owner).send(msg.value)); // Ethereum will be sent to ERC20 contract.

        payment = msg.value * exchangeRate;
        require(tokenReward.isOwnerPayable(payment));
        require(tokenReward.transferFrom(address(owner), msg.sender, msg.value * exchangeRate));
        success = true;
        return success;
    }

}
