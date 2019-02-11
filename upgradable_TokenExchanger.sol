// contract version 0.2.8
// 변경사항
// 1. 기존 구조에서 변수를 추가하는 수정을 했을경우 사용하던 데이터들의 순서가 꼬여버리는 버그 수정
//    ProxyNemodax 컨트랙트가 가진 실 데이터 저장 순서중에 가장 마지막에 위치했었던 implementation 변수를 Pausable 컨트랙트의 pause 변수 다음으로 순서 변경
//    이렇게 하면 변수를 추가하는 수정시 tokenPerEth 변수를 제외한 가장 마지막에 추가할 경우 ERC20 변수들의 사용 데이터를 훼손하지 않음
//    * 주의할점 : 향후 TokenERC20 컨트랙트의 변수 추가후 주소변경시(tokenPerEth보다 추가된 변수의 순서가 앞서기 때문에 tokenPerEth의 메모리 번지가 뒤로 밀림)
//               tokenPerEth 데이터가 훼손되기 때문에 반드시 초기화할것.
//
//    즉 ProxyNemodax가 가지게 되는 전체 상속관계와 데이터의 순서는 다음과 같음
//    ================================================================================
//    상속관계
//    Ownerable <- Pausable <- RunningConctractManager <- TokenERC20 <- TokenExchanger
//
//    Ownerable <- Pausable <- RunningContracttManager <- NemodaxStorage <- ProxyNemodax
//    ================================================================================
//    ProxyNemodax가 가진 실제 저장 변수들의 메모리 번지 순서
//    address payable internal owner;
//    bool internal paused;
//    address internal implementation;
//
//    string public name;
//    string public symbol;
//    uint8 public decimals = 18;
//    uint256 public totalSupply;
//
//    mapping (address => uint256) public balances;
//    mapping (address => mapping (address => uint256))
//    mapping (address => bool) public frozenAccount;
//
//    uint256 public tokenPerEth;
//    =================================================================================


// contract version 0.2.7
// upgrade시 0 address 체크로직 추가
// initExchanger 함수 tokenPerEth 파라미터 데이터타입 uint => uint256으로 명시


// contract version 0.2.6
// 0x499b94c686aba85190bb1379633cfe2a6fd8304f
// upgrade 함수 onlyOwner로 변경하여 마스터 계정만 컨트랙트 수정이 가능토록 변경함.
// v0.2.6 버전 추가 테스트 내용
// 1. 일반계정은 재 init 정상 실패 확인, 단 마스터 계정은 재 init이 가능하기 때문에 꼭! 다시 init하지 않도록 각별히 주의할것
// 2. 마스터가 아닌 일반계정으로 컨트랙트 변경(업그레이드) 시도시 정상 실패 확인
// 3. 일반계정 transferFrom 성공확인(approve, allowance 정상 동작 확인 포함)
// 4. Exchanger 컨트랙트 수정은 가능하나 새로운 변수를 추가하는 것은 불가함.
//    실제 저장은 ProxyNemodax에 되며 상속하고 있는 NemodaxStorage에 등록되어 있는 변수만 사용 가능하기 때문에
//    NemodaxStorage 를 수정후 ProxyNemodax를 재배포하지 않는한
//    Exchanger 또는 ERC20 컨트랙트에 변수를 추가한다 하여도 사용이 불가함.
// 5. 마스터계정에 의한 freeze시 송금 불가 확인 / unfreeze시 송금 가능 확인
// 6. pause/unpause 기능 정상작동 확인 (transfer, transferFrom, approve, exchangeEtherToToken 등등 사용불가 확인.)
// 7. 솔리디티는 소수표시가 안되는데 tokenPerEth로는 이더보다 코인의 가치가 커졌을때 어떻게 표현할까?


// v0.2.5 테스트 내용
// 1. 마스터 계정 init 성공 (일반계정은 재 init 실패, 단 마스터 계정은 재 init이 가능하기 때문에 꼭! 다시 init하지 않도록 각별히 주의할것)
// 2. 이더 잔액 확인 성공
// 3. 코인 잔액 확인 성공
// 4. 마스터 => 일반 계정 송금 성공
// 5. 일반 계정 => 일반 계정 송금 성공
// 6. 사용자 / 마스터 계정 언락 성공
// 7. 환율 마스터 계정만 환율 확인 안됨 성공
// 8. 환율 마스터 계정만 변경 성공
// 9. 이더 -> 코인 교환 성공
// 10. 코인 -> 이더 교환 성공
// 11. 코인 출금 마스터만 성공
// 12. 이더 출금 마스터만 성공
// 13. Exchanger 컨트랙트 교체 /수정시 사용하던 코인정보가(계좌 잔액들, 코인 메타 정보, 통화량 등등) 그대로 남아있는지 테스트 => 정상 확인.



pragma solidity ^0.5.2;


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
    address payable internal owner;

    /* you have to use this contract to be inherited because it is internal.*/
    constructor() internal {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address payable newOwner) onlyOwner public {
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

contract RunningConctractManager is Pausable{
    address internal implementation;

    event Upgraded(address indexed newContract);

    function upgrade(address _newAddr) onlyOwner external {
        require(implementation != _newAddr);
        implementation = _newAddr;
        //emit Upgraded(implementation);
    }
    //when it will be released, will be deleted.
    function runningAddress() onlyOwner external view returns (address){
        return implementation;
    }
}



/**
 * NemoLab ERC20 Token
 * Written by Shin HyunJae
 * version 12
 */
contract TokenERC20 is RunningConctractManager {
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
     */
    //uint256 something..;

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

    function initToken(
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _initialSupply
    ) internal onlyOwner {
        name = _tokenName;                                       // Set the name for display purposes
        symbol = _tokenSymbol;                                   // Set the symbol for display purposes
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



contract TokenExchanger is TokenERC20{
  using SafeMath for uint256;

    uint256 private tokenPerEth;

    event ReceiveEther(address indexed from, uint256 value);
    event ReceiveToken(address indexed from, uint256 value);
    event ExchangeEtherToToken(address indexed from, uint256 etherValue, uint256 tokenPerEth);
    event ExchangeTokenToEther(address indexed from, uint256 etherValue, uint256 tokenPerEth);
    event WithdrawToken(address indexed to, uint256 value);
    event WithdrawEther(address indexed to, uint256 value);



    function initExchanger(
        string calldata _tokenName,
        string calldata _tokenSymbol,
        uint256 _initialSupply,
        uint256 _tokenPerEth
    ) external onlyOwner {
        require(_tokenPerEth > 0);

        super.initToken(_tokenName, _tokenSymbol, _initialSupply);
        tokenPerEth = _tokenPerEth;
    }


    function setExchangeRate(uint256 _tokenPerEth) onlyOwner external returns (bool success){
        require( _tokenPerEth > 0);
        tokenPerEth = _tokenPerEth;
        success = true;
        return success;
    }

    function getExchangerRate() onlyOwner external view returns(uint){
        return tokenPerEth;
    }

    //1. 이더받고 토큰으로 전송
    function exchangeEtherToToken() payable external noReentrancy returns (bool success){
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

    //2. 토큰받고 이더로 전송
    function exchangeTokenToEther(uint256 _value) external noReentrancy returns (bool success){
      require(tokenPerEth != 0);

      uint256 remainingEthBalance = address(this).balance;
      uint256 etherPayment = _value.div(tokenPerEth);
      require(remainingEthBalance >= etherPayment);

      super._transfer(msg.sender, address(this), _value);
      require(address(msg.sender).send(etherPayment));

      emit ExchangeTokenToEther(address(this), etherPayment, tokenPerEth);
      success = true;
      return success;
    }

    //3. 토큰 인출
    function withdrawToken(address _recipient, uint256 _value) onlyOwner noReentrancy public{
      super._transfer(address(this) ,_recipient, _value);
      emit WithdrawEther(_recipient, _value);

    }
    //4. 토큰 받기

    //5. 이더 송금
    function withdrawEther(address payable _recipient, uint256 _value) onlyOwner noReentrancy public {
        require(_recipient.send(_value));
        emit WithdrawEther(_recipient, _value);

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
    function destroyAndSend(address payable _recipient) public onlyOwner {
        uint256 tokenBalance = super.balanceOf(address(this));
        require(tokenBalance == 0); // Check if this contract have remaining tokens
        selfdestruct(_recipient);
    }

}


/**
 * NemodaxStorage Contract shouldn't be changed as possible.
 * If it should be edited, please add from the end of the contract .
 */

contract NemodaxStorage is RunningConctractManager{

    // Never ever change the order of variables below!!!!
    // Public variables of the token
    string public name;
    string public symbol;
    uint8 public decimals = 18;    // 18 decimals is the strongly suggested default, avoid changing it
    uint256 public totalSupply;

    /* This creates an array with all balances */
    mapping (address => uint256) public balances;
    mapping (address => mapping (address => uint256)) public allowed;
    mapping (address => bool) public frozenAccount;

    uint256 public tokenPerEth;


    constructor() Ownable() internal {}

}


contract ProxyNemodax is NemodaxStorage  {

    function () payable external {
        address localImpl = implementation;
        require(localImpl != address(0));

        assembly {
            let ptr := mload(0x40)

            switch calldatasize
            case 0 {  } // just to receive ethereum

            default{
                calldatacopy(ptr, 0, calldatasize)

                let result := delegatecall(gas, localImpl, ptr, calldatasize, 0, 0)
                let size := returndatasize
                returndatacopy(ptr, 0, size)
                switch result

                case 0 { revert(ptr, size) }
                default { return(ptr, size) }
            }
        }
    }
}
