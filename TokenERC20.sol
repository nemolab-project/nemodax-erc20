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

interface tokenRecipient {
  function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) external;
}

interface tokenExchanger {
  function exchangeTokenToEther(address _recipient, uint256 _value, uint256 _exchangeRate) external returns (bool success);
  // function withdrawEther(address _recipient, uint256 _value) external;
}

/**
 * NemoLab ERC20 Token
 * Written by Shin HyunJae
 * version 12
 */
contract TokenERC20 is Pausable {
    using SafeMath for uint256;

    // Public variables of the token
    string public name;
    string public symbol;
    uint8 public decimals = 18;    // 18 decimals is the strongly suggested default, avoid changing it
    uint256 public totalSupply;

    /* This creates an array with all balances */
    mapping (address => uint256) public balances;
    mapping (address => mapping (address => uint256)) public allowed;
    mapping (address => bool) public frozenAccount;

    // This generates a public event on the blockchain that will notify clients
    event Transfer(address indexed from, address indexed to, uint256 value);
    event LastBalance(address indexed account, uint256 value);

    // This notifies clients about the allowance of balance
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    // This notifies clients about the amount burnt
    event Burn(address indexed from, uint256 value);

    // This notifies clients about the amount resupplied
    event Resupply(address indexed from, uint256 value);

    // This notifies clients about the freezing address
    event FrozenFunds(address target, bool frozen);

    /**
     * Constructor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    constructor(string tokenName, string tokenSymbol, uint256 initialSupply) public {
        name = tokenName;                                       // Set the name for display purposes
        symbol = tokenSymbol;                                   // Set the symbol for display purposes
        totalSupply = convertToDecimalUnits(initialSupply);     // Update total supply with the decimal amount
        balances[msg.sender] = totalSupply;                     // Give the creator all initial tokens
        emit Transfer(address(this), msg.sender, totalSupply);
        emit LastBalance(address(this), 0);
        emit LastBalance(msg.sender, totalSupply);
    }

    /**
     * Convert tokens units to token decimal units
     *
     * @param _value Tokens units without decimal units
     */
    function convertToDecimalUnits(uint256 _value) internal view returns (uint256 value) {
        value = _value.mul(10 ** uint256(decimals));
        return value;
    }

    /**
     * Get tokens balance
     *
     * @notice Query tokens balance of the _account
     *
     * @param _account Account address to query tokens balance
     */
    function balanceOf(address _account) external view returns (uint256 balance) {
        balance = balances[_account];
        return balance;
    }

    /**
     * Get allowed tokens balance
     *
     * @notice Query tokens balance allowed to _spender
     *
     * @param _owner Owner address to query tokens balance
     * @param _spender The address allowed tokens balance
     */
    function allowance(address _owner, address _spender) external view returns (uint256 remaining) {
        remaining = allowed[_owner][_spender];
        return remaining;
    }

    /**
     * Internal transfer, only can be called by this contract
     */
    function _transfer(address _from, address _to, uint256 _value) internal {
        require(_to != 0x0);                                            // Prevent transfer to 0x0 address. Use burn() instead
        require(balances[_from] >= _value);                             // Check if the sender has enough
        require(!frozenAccount[_from]);                                 // Check if sender is frozen
        require(!frozenAccount[_to]);                                   // Check if recipient is frozen
        uint256 previousBalances = balances[_from].add(balances[_to]);  // Save this for an assertion in the future

        balances[_from] = balances[_from].sub(_value);                  // Subtract from the sender
        balances[_to] = balances[_to].add(_value);                      // Add the same to the recipient
        emit Transfer(_from, _to, _value);
        emit LastBalance(_from, balances[_from]);
        emit LastBalance(_to, balances[_to]);

        // Asserts are used to use static analysis to find bugs in your code. They should never fail
        assert(balances[_from] + balances[_to] == previousBalances);
    }

    /**
     * Transfer tokens
     *
     * @notice Send `_value` tokens to `_to` from your account
     *
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transfer(address _to, uint256 _value) public noReentrancy returns (bool success) {
        _transfer(msg.sender, _to, _value);
        success = true;
        return success;
    }


    /**
     * Transfer tokens from other address
     *
     * Send `_value` tokens to `_to` on behalf of `_from`
     *
     * @param _from The address of the sender
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transferFrom(address _from, address _to, uint256 _value) public noReentrancy returns (bool success) {
        require(_value <= allowed[_from][msg.sender]);     // Check allowance
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        _transfer(_from, _to, _value);
        success = true;
        return success;
    }

    function transferToExchangerAndCall(address _to, uint256 _value, uint256 _exchangeRate) public noReentrancy returns (bool success){
        tokenExchanger exchanger = tokenExchanger(_to);
        _transfer(msg.sender, _to, _value);

        exchanger.exchangeTokenToEther(msg.sender, _value, _exchangeRate);
        success = true;
        return success;
    }
    /**
     * Internal approve, only can be called by this contract
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     */
    function _approve(address _spender, uint256 _value) internal returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        success = true;
        return success;
    }

    /**
     * Set allowance for other address
     *
     * Allows `_spender` to spend no more than `_value` tokens on your behalf
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     */
    function approve(address _spender, uint256 _value) public noReentrancy returns (bool success) {
        success = _approve(_spender, _value);
        return success;
    }

    /**
     * Set allowance for other address and notify
     *
     * @notice Allows `_spender` to spend no more than `_value` tokens on your behalf, and then ping the contract about it
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     * @param _extraData some extra information to send to the approved contract
     */
    function approveAndCall(address _spender, uint256 _value, bytes _extraData) public noReentrancy returns (bool success) {
        tokenRecipient spender = tokenRecipient(_spender);
        if (_approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, this, _extraData);
            success = true;
            return success;
        }
    }

    /**
     * Destroy tokens
     *
     * Remove `_value` tokens from the system irreversibly
     *
     * @param _value the amount of money to burn
     */
    function burn(uint256 _value) onlyOwner public returns (bool success) {
        require(balances[msg.sender] >= _value);                            // Check if the sender has enough
        balances[msg.sender] = balances[msg.sender].sub(_value);            // Subtract from the sender
        totalSupply = totalSupply.sub(_value);                              // Updates totalSupply
        emit Burn(msg.sender, _value);
        success = true;
        return success;
    }

    /**
     * Destroy tokens from other account
     *
     * @notice Remove `_value` tokens from the system irreversibly on behalf of `_from`.
     *
     * @param _from the address of the sender
     * @param _value the amount of money to burn
     */
    function burnFrom(address _from, uint256 _value) onlyOwner public returns (bool success) {
        require(balances[_from] >= _value);                                         // Check if the targeted balance is enough
        require(allowed[_from][msg.sender] >= _value);                              // Check allowance
        balances[_from] = balances[_from].sub(_value);                              // Subtract from the targeted balance
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);        // Subtract from the sender's allowance
        totalSupply = totalSupply.sub(_value);                                      // Update totalSupply
        emit Burn(_from, _value);
        success = true;
        return success;
    }

    /// @notice `freeze? Prevent` `target` from sending & receiving tokens
    /// @param target Address to be frozen
    function freezeAccount(address target) onlyOwner public {
        frozenAccount[target] = true;
        emit FrozenFunds(target, true);
    }

    /// @notice `freeze? Allow` `target` from sending & receiving tokens
    /// @param target Address to be unfrozen
    function unfreezeAccount(address target) onlyOwner public {
        frozenAccount[target] = false;
        emit FrozenFunds(target, false);
    }

}


interface token {
    function transfer(address _to, uint256 _value) external returns (bool success);
    function balanceOf(address _account) external view returns (uint256 balance);
}


contract TokenExchanger is Pausable {
  using SafeMath for uint256;
    token public tokenReward;
    address private tokenAddress;
    uint256 private exchangeRate;

    event ReceiveEther(address indexed from, uint256 value);
    event ReceiveToken(address indexed from, uint256 value);
    event ExchangeEtherToToken(address indexed from, uint256 etherValue, uint256 exchangeRate);
    event ExchangeTokenToEther(address indexed from, uint256 etherValue, uint256 exchangeRate);
    event WithdrawToken(address indexed to, uint256 value);
    event WithdrawEther(address indexed to, uint256 value);

    constructor(
        address addressOfTokenUsedAsReward // nomo token contract
    ) public {
        tokenAddress = addressOfTokenUsedAsReward;
        tokenReward = token(addressOfTokenUsedAsReward);
    }

    function setExchangeRate(uint256 _value) onlyowner external returns (bool success){
      setExchangeRate = _value;
      success = true;
      return success;
    }

    //1. 이더받고 토큰으로 전송
    function exchangeEtherToToken() payable external returns (bool success){

        uint256 tokenPayment;
        uint256 amount = msg.value;
        //Secure issues
        //amount가 엄청 크면?? -> overflow 위험
        // uint256의 최대값은 2^256-1 = 115792089237316195423570985008687907853269984665640564039457584007913129639935
        //amount가 엄청 음수로 작으면? -> underflow 위험
        //amount가 소수면? -> 소수 지원안함 -> amount가 소수일수 없음
        //amount가 0이면? -> solve: require(amount > 0)
        require(amount > 0);
        require(exchangeRate != 0);
        tokenPayment = amount.mul(exchangeRate);

        require(tokenReward.balanceOf(address(this)) >= tokenPayment);
        tokenReward.transfer(msg.sender, tokenPayment);
        emit ExchangeEtherToToken(msg.sender, msg.value, exchangeRate);

        success = true;
        return success;
    }

    //2. 토큰받고 이더로 전송
    function exchangeTokenToEther(address _recipient, uint256 _value, uint256 _exchangeRate) external returns (bool success){
      uint256 remainingBalance = address(this).balance;
      uint256 etherPayment = _value.div(_exchangeRate);

      require(tokenAddress == msg.sender);
      require(remainingBalance >= etherPayment);
      if (_recipient.send(etherPayment)) {
          emit ExchangeTokenToEther(address(this), etherPayment, _exchangeRate);
      }

      success = true;
      return success;
    }

    //3. 토큰 인출
    function withdrawToken(address _recipient, uint256 _value) onlyOwner public{
      uint256 tokenBalance = tokenReward.balanceOf(this);
      require(tokenBalance >= _value);
      if (tokenReward.transfer(_recipient, _value)) {
          emit WithdrawEther(_recipient, _value);
      }
    }
    //4. 토큰 ㅂ받기

    //5. 이더 송금
    function withdrawEther(address _recipient, uint256 _value) onlyOwner public {
        uint256 remainingBalance = address(this).balance;
        require(remainingBalance >= _value);
        if (_recipient.send(_value)) {
            emit WithdrawEther(_recipient, _value);
        }
    }
    //6. 이더 받기
    function () payable public {
      emit ReceiveEther(msg.sender, msg.value);
    }

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
