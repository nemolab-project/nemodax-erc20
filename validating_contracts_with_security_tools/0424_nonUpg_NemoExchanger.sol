pragma solidity 0.4.24;

// [v0.2.10] validating contract
// 1. solidity compiler 버전 0.4.24로 다운그레이드 <- 검증툴 지원 컴파일러 버전을 맞추기 위함
// 2. pragma '^' 삭제 (smart check 권고사항)
// 3. 발행 코인 수 체크구문 추가 (mythril 권고사항 0<_initialSupply <= 2^184)
// 4. Token -> Ether 교환시 교환비로 나누어 떨어지지 않는 Token을 입금할 경우 나머지는 빼고 토큰 입금 받는 것으로 로직 수정
// (ex. tokenPerEth=3 일 경우 10개의 Token을 교환해달라는 요청을 받으면 3 wei로 교환이 가능하지만 1 Token은 wei로 교환이 불가능하므로 10 토큰 청을 받아도 9개 토큰만 3wei로 교환해준다.)

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
      return 0;
    }

    c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return a / b;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}



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

    /**
     * This is area for some variables to add.
     * Please add variables from the end of pre-declared variables
     * if you would have added some variables and re-deployed the contract,
     * tokenPerEth would get garbage value. so please reset tokenPerEth variable
     *
     * uint256 something..;
     */


    // This generates a public event on the blockchain that will notify clients
    event Transfer(address indexed from, address indexed to, uint256 value);
    event LastBalance(address indexed account, uint256 value);

    // This notifies clients about the allowance of balance
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    // This notifies clients about the amount burnt
    event Burn(address indexed from, uint256 value);

    // This notifies clients about the freezing address
    event FrozenFunds(address target, bool frozen);

    /**
     * Constructor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */

    function initToken(
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _initialSupply
    ) internal onlyOwner {
        name = _tokenName;                                       // Set the name for display purposes
        symbol = _tokenSymbol;                                   // Set the symbol for display purposes

        require(_initialSupply > 0 && _initialSupply <= 2**uint256(184)); // [2019.03.05] Fixed for Mythril Vulerablity SWC ID:101 => _initialSupply <= 2^184 <= (2^256 / 10^18)
        totalSupply = convertToDecimalUnits(_initialSupply);     // Update total supply with the decimal amount

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
    function balanceOf(address _account) public view returns (uint256 balance) {
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
        require(_to != address(0x0));                                            // Prevent transfer to 0x0 address. Use burn() instead
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


/**
 * @title NemoExchanger
 * @notice This is for exchange between Ether and 'Nemo' token
 *          It won't be needed after being listed on the exchange.
 */

contract NemoExchanger is TokenERC20{
  using SafeMath for uint256;

    uint256 internal tokenPerEth;
    bool private exchangeOpened = true;

    event ExchangeEtherToToken(address indexed from, uint256 etherValue, uint256 tokenPerEth);
    event ExchangeTokenToEther(address indexed from, uint256 etherValue, uint256 tokenPerEth);
    event ReserveEther(address indexed from, uint256 value);
    event ReserveToken(address indexed from, uint256 alue);
    event WithdrawToken(address indexed to, uint256 value);
    event WithdrawEther(address indexed to, uint256 value);
    event SetExchangeRate(address indexed from, uint256 tokenPerEth);


    modifier isOpen() {
        require(exchangeOpened == true);
        _;
    }

    function initExchanger(
        string _tokenName,
        string _tokenSymbol,
        uint256 _initialSupply,
        uint256 _tokenPerEth
    ) external onlyOwner {
        require(_tokenPerEth > 0 && _initialSupply > 0);  // [2019.03.05] Fixed for Mythril Vulerablity SWC ID:101

        super.initToken(_tokenName, _tokenSymbol, _initialSupply);
        tokenPerEth = _tokenPerEth;
        emit SetExchangeRate(msg.sender, tokenPerEth);
    }

    /**
     * set the setExchangeClosed variable flag
     *
     * set the setExchangeClosed variable flag true to open this tokens exchanger
     */
    function setExchangeOpened() isOpen onlyOwner external {
        exchangeOpened = false;
    }

    function getExchangeOpened() isOpen external view returns (bool _exchangeOpened) {
        _exchangeOpened = exchangeOpened;
        return _exchangeOpened;
    }


    function setExchangeRate(uint256 _tokenPerEth) isOpen onlyOwner external returns (bool success){
        require( _tokenPerEth > 0);
        tokenPerEth = _tokenPerEth;
        emit SetExchangeRate(msg.sender, tokenPerEth);

        success = true;
        return success;
    }

    function getExchangerRate() isOpen onlyOwner external view returns(uint256){
        return tokenPerEth;
    }

    /**
     * Exchange Ether To Token
     *
     * @notice Send `Nemo` tokens to msg sender as much as amount of ether received considering exchangeRate.
     */
    function exchangeEtherToToken() payable external isOpen noReentrancy returns (bool success){
        uint256 tokenPayment;
        uint256 ethAmount = msg.value;

        require(ethAmount > 0);
        require(tokenPerEth != 0);
        tokenPayment = ethAmount.mul(tokenPerEth);

        super._transfer(address(this), msg.sender, tokenPayment);

        emit ExchangeEtherToToken(msg.sender, msg.value, tokenPerEth);

        success = true;
        return success;
    }

    /**
     * Exchange Token To Ether
     *
     * @notice Send Ether to msg sender as much as amount of 'Nemo' Token received considering exchangeRate.
     *
     * @param _value Amount of 'Nemo' token
     */
    function exchangeTokenToEther(uint256 _value) external isOpen noReentrancy returns (bool success){
      require(tokenPerEth != 0);

      uint256 remainingEthBalance = address(this).balance;
      uint256 etherPayment = _value.div(tokenPerEth);
      uint256 remainder = _value % tokenPerEth; // [2019.03.06 Fixing Securify vulnerabilities-Division influences Transfer Amount]
      require(remainingEthBalance >= etherPayment);

      uint256 tokenAmount = _value.sub(remainder); // [2019.03.06 Fixing Securify vulnerabilities-Division influences Transfer Amount]
      super._transfer(msg.sender, address(this), tokenAmount); // [2019.03.06 Fixing Securify vulnerabilities-Division influences Transfer Amount]
      require(address(msg.sender).send(etherPayment));

      emit ExchangeTokenToEther(address(this), etherPayment, tokenPerEth);
      success = true;
      return success;
    }

    /**
     * Reserve Ether
     *
     * @notice Send Ether to NemoExchanger for exchange service.
     */
    function reserveEther() payable isOpen onlyOwner external {
      emit ReserveEther(msg.sender, msg.value);
    }

    /**
     * Reserve Token
     *
     * @notice Send `Nemo` tokens to NemoExchanger for exchange service.
     */
    function reserveToken(uint256 _value) isOpen onlyOwner external {
      super._transfer(msg.sender, address(this), _value);
      emit ReserveToken(msg.sender, _value);
    }

    /**
     * Withdraw token from NemoExchanger contract
     *
     * @notice Withdraw charged Token to _recipient.
     *
     * @param _recipient The address to which the token was issued.
     * @param _value Amount of token to withdraw.
     */
    function withdrawToken(address _recipient, uint256 _value) onlyOwner noReentrancy public {
      super._transfer(address(this) ,_recipient, _value);
      emit WithdrawToken(_recipient, _value);
    }


    /**
     * Withdraw Ether from NemoExchanger contract
     *
     * @notice Withdraw charged Ether to _recipient.
     *
     * @param _recipient The address to which the Ether was issued.
     * @param _value Amount of Ether to withdraw.
     */
    function withdrawEther(address _recipient, uint256 _value) onlyOwner noReentrancy public {
        require(_recipient.send(_value));
        emit WithdrawEther(_recipient, _value);

    }

}
