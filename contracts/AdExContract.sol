pragma solidity ^0.4.11;


// TODO:
// openzeppelin for everything up to ADX
// vesting tokens (12m, 3m cliff)

// https://github.com/OpenZeppelin/zeppelin-solidity/blob/v1.0.7/contracts/SafeMath.sol
/**
 * Math operations with safety checks
 */
library SafeMath {
  function mul(uint a, uint b) internal returns (uint) {
    uint c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint a, uint b) internal returns (uint) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint a, uint b) internal returns (uint) {
    assert(b <= a);
    return a - b;
  }

  function add(uint a, uint b) internal returns (uint) {
    uint c = a + b;
    assert(c >= a);
    return c;
  }

  function max64(uint64 a, uint64 b) internal constant returns (uint64) {
    return a >= b ? a : b;
  }

  function min64(uint64 a, uint64 b) internal constant returns (uint64) {
    return a < b ? a : b;
  }

  function max256(uint256 a, uint256 b) internal constant returns (uint256) {
    return a >= b ? a : b;
  }

  function min256(uint256 a, uint256 b) internal constant returns (uint256) {
    return a < b ? a : b;
  }

  function assert(bool assertion) internal {
    if (!assertion) {
      throw;
    }
  }
}


// https://github.com/OpenZeppelin/zeppelin-solidity/blob/v1.0.7/contracts/token/ERC20Basic.sol
/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20Basic {
  uint public totalSupply;
  function balanceOf(address who) constant returns (uint);
  function transfer(address to, uint value);
  event Transfer(address indexed from, address indexed to, uint value);
}


// https://github.com/OpenZeppelin/zeppelin-solidity/blob/v1.0.7/contracts/token/ERC20.sol
/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) constant returns (uint);
  function transferFrom(address from, address to, uint value);
  function approve(address spender, uint value);
  event Approval(address indexed owner, address indexed spender, uint value);
}


// https://github.com/OpenZeppelin/zeppelin-solidity/blob/v1.0.7/contracts/token/BasicToken.sol
/**
 * @title Basic token
 * @dev Basic version of StandardToken, with no allowances. 
 */
contract BasicToken is ERC20Basic {
  using SafeMath for uint;

  mapping(address => uint) balances;

  /**
   * @dev Fix for the ERC20 short address attack.
   */
  modifier onlyPayloadSize(uint size) {
     if(msg.data.length < size + 4) {
       throw;
     }
     _;
  }

  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint _value) onlyPayloadSize(2 * 32) {
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Transfer(msg.sender, _to, _value);
  }

  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of. 
  * @return An uint representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) constant returns (uint balance) {
    return balances[_owner];
  }

}

// https://github.com/OpenZeppelin/zeppelin-solidity/blob/v1.0.7/contracts/token/StandardToken.sol
/**
 * @title Standard ERC20 token
 *
 * @dev Implemantation of the basic standart token.
 * @dev https://github.com/ethereum/EIPs/issues/20
 * @dev Based on code by FirstBlood: https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
 */
contract StandardToken is BasicToken, ERC20 {

  mapping (address => mapping (address => uint)) allowed;


  /**
   * @dev Transfer tokens from one address to another
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint the amout of tokens to be transfered
   */
  function transferFrom(address _from, address _to, uint _value) onlyPayloadSize(3 * 32) {
    var _allowance = allowed[_from][msg.sender];

    // Check is not needed because sub(_allowance, _value) will already throw if this condition is not met
    // if (_value > _allowance) throw;

    balances[_to] = balances[_to].add(_value);
    balances[_from] = balances[_from].sub(_value);
    allowed[_from][msg.sender] = _allowance.sub(_value);
    Transfer(_from, _to, _value);
  }

  /**
   * @dev Aprove the passed address to spend the specified amount of tokens on beahlf of msg.sender.
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint _value) {

    // To change the approve amount you first have to reduce the addresses`
    //  allowance to zero by calling `approve(_spender, 0)` if it is not
    //  already 0 to mitigate the race condition described here:
    //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    if ((_value != 0) && (allowed[msg.sender][_spender] != 0)) throw;

    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
  }

  /**
   * @dev Function to check the amount of tokens than an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param _spender address The address which will spend the funds.
   * @return A uint specifing the amount of tokens still avaible for the spender.
   */
  function allowance(address _owner, address _spender) constant returns (uint remaining) {
    return allowed[_owner][_spender];
  }

}


contract ADX is StandardToken {

	//FIELDS
	string public name = "AdEx";
	string public symbol = "ADX";
	uint public decimals = 4;

	//CONSTANTS
	uint public constant LOCKOUT_PERIOD = 1 years; //time after end date that illiquid ADX can be transferred

	//ASSIGNED IN INITIALIZATION
	uint public endMintingTime; //Timestamp after which no more tokens can be created
	uint public finalSupply; //Amount after which no more tokens can be created
	address public minter; //address of the account which may mint new tokens

	mapping (address => uint) public illiquidBalance; //Balance of 'Frozen funds'

	//MODIFIERS
	//Can only be called by contribution contract.
	modifier only_minter {
		if (msg.sender != minter) throw;
		_;
	}

	// Can only be called if illiquid tokens may be transformed into liquid.
	// This happens when `LOCKOUT_PERIOD` of time passes after `endMintingTime`.
	modifier when_thawable {
		if (now < endMintingTime + LOCKOUT_PERIOD) throw;
		_;
	}

	// Can only be called if (liquid) tokens may be transferred. Happens
	// immediately after `endMintingTime` or once the 'ALLOC_CROWDSALE' has been reached.
	modifier when_transferable {
		if ((now < endMintingTime && totalSupply < finalSupply)) throw;
		_;
	}

	// Can only be called if the `crowdfunder` is allowed to mint tokens. Any
	// time before ` endMintingTime`.
	modifier when_mintable {
		if (now >= endMintingTime) throw;
		_;
	}

	// Initialization contract assigns address of crowdfund contract and end time.
	function ADX(address _minter, uint _endMintingTime, uint _finalSupply) {
		endMintingTime = _endMintingTime;
		finalSupply = _finalSupply;
		minter = _minter;
	}

	// Create new tokens when called by the crowdfund contract.
	// Only callable before the end time.
	function createToken(address _recipient, uint _value)
		when_mintable
		only_minter
		returns (bool o_success)
	{
		balances[_recipient] += _value;
		totalSupply += _value;
		return true;
	}

	// Create an illiquidBalance which cannot be traded until end of lockout period.
	// Can only be called by crowdfund contract before the end time.
	function createIlliquidToken(address _recipient, uint _value)
		when_mintable
		only_minter
		returns (bool o_success)
	{
		illiquidBalance[_recipient] += _value;
		totalSupply += _value;
		return true;
	}

	// Make sender's illiquid balance liquid when called after lockout period.
	function makeLiquid()
		when_thawable
	{
		//uint allReleasable = 
		//uint releasedSoFar = illiquidInitial[msg.sender] - illiquidBalance[msg.sender];
		//allReleasable - releasedSoFar
		balances[msg.sender] += illiquidBalance[msg.sender];
		illiquidBalance[msg.sender] = 0;
	}

	// Transfer amount of tokens from sender account to recipient.
	// Only callable after the crowd fund end date.
	function transfer(address _from, uint _to)
		when_transferable
	{
		super.transfer(_from, _to);
	}

	// Transfer amount of tokens from a specified address to a recipient.
	// Only callable after the crowd fund end date.
	function transferFrom(address _from, address _to, uint _value)
		when_transferable
	{
		super.transferFrom(_from, _to, _value);
	}
}


contract Contribution {

	//FIELDS

	//CONSTANTS
	//Time limits
	uint public constant STAGE_ONE_TIME_END = 24 hours; // first day bonus
	uint public constant STAGE_TWO_TIME_END = 1 weeks;
	uint public constant STAGE_THREE_TIME_END = 2 weeks;
	uint public constant STAGE_FOUR_TIME_END = 4 weeks;
	

	// Decimals
	// WARNING: Must be synced up with ADX.decimals
	uint private constant DECIMALS = 10000;

	//Prices of ADX
	uint public constant PRICE_STANDARD    = 900*DECIMALS; // ADX received per one ETH; MAX_SUPPLY / (valuation / ethPrice)
	uint public constant PRICE_STAGE_ONE   = PRICE_STANDARD * 100/30;
	uint public constant PRICE_STAGE_TWO   = PRICE_STANDARD * 100/15;
	uint public constant PRICE_STAGE_THREE = PRICE_STANDARD;
	uint public constant PRICE_STAGE_FOUR  = PRICE_STANDARD;
	uint public constant PRICE_PREBUY      = PRICE_STANDARD * 100/30; // 20% bonus will be given from illiquid tokens-

	//ADX Token Limits
	uint public constant MAX_SUPPLY =        100000000*DECIMALS;
	uint public constant ALLOC_ILLIQUID_TEAM = 8000000*DECIMALS;
	uint public constant ALLOC_LIQUID_TEAM =  10000000*DECIMALS;
	uint public constant ALLOC_BOUNTIES =      2000000*DECIMALS;
	uint public constant ALLOC_NEW_USERS =    40000000*DECIMALS;
	uint public constant ALLOC_CROWDSALE =    40000000*DECIMALS;
	uint public constant PREBUY_PORTION_MAX = 32 * DECIMALS * PRICE_PREBUY;
	
	//ASSIGNED IN INITIALIZATION
	//Start and end times
	uint public publicStartTime; //Time in seconds public crowd fund starts.
	uint public privateStartTime; //Time in seconds when pre-buy can purchase up to 31250 ETH worth of ADX;
	uint public publicEndTime; //Time in seconds crowdsale ends
	
	//Special Addresses
	address public prebuyAddress; //Address used by pre-buy
	address public multisigAddress; //Address to which all ether flows.
	address public adexAddress; //Address to which ALLOC_BOUNTIES, ALLOC_LIQUID_TEAM, ALLOC_NEW_USERS, ALLOC_ILLIQUID_TEAM is sent to.
	address public ownerAddress; //Address of the contract owner. Can halt the crowdsale.
	
	//Contracts
	ADX public ADXToken; //External token contract hollding the ADX
	
	//Running totals
	uint public etherRaised; //Total Ether raised.
	uint public ADXSold; //Total ADX created
	uint public prebuyPortionTotal; //Total of Tokens purchased by pre-buy. Not to exceed PREBUY_PORTION_MAX.
	
	//booleans
	bool public halted; //halts the crowd sale if true.

	//FUNCTION MODIFIERS

	//Is currently in the period after the private start time and before the public start time.
	modifier is_pre_crowdfund_period() {
		if (now >= publicStartTime || now < privateStartTime) throw;
		_;
	}

	//Is currently the crowdfund period
	modifier is_crowdfund_period() {
		if (now < publicStartTime || now >= publicEndTime) throw;
		_;
	}

	//May only be called by pre-buy
	modifier only_prebuy() {
		if (msg.sender != prebuyAddress) throw;
		_;
	}

	//May only be called by the owner address
	modifier only_owner() {
		if (msg.sender != ownerAddress) throw;
		_;
	}

	//May only be called if the crowdfund has not been halted
	modifier is_not_halted() {
		if (halted) throw;
		_;
	}

	// EVENTS

	event PreBuy(uint _amount);
	event Buy(address indexed _recipient, uint _amount);


	// FUNCTIONS

	//Initialization function. Deploys ADXToken contract assigns values, to all remaining fields, creates first entitlements in the ADX Token contract.
	function Contribution(
		address _prebuy,
		address _multisig,
		address _adex,
		uint _publicStartTime,
		uint _privateStartTime
	) {
		ownerAddress = msg.sender;
		publicStartTime = _publicStartTime;
		privateStartTime = _privateStartTime;
		publicEndTime = _publicStartTime + 4 weeks;
		prebuyAddress = _prebuy;
		multisigAddress = _multisig;
		adexAddress = _adex;
		ADXToken = new ADX(this, publicEndTime, MAX_SUPPLY);
		ADXToken.createIlliquidToken(adexAddress, ALLOC_ILLIQUID_TEAM);
		ADXToken.createToken(adexAddress, ALLOC_BOUNTIES);
		ADXToken.createToken(adexAddress, ALLOC_LIQUID_TEAM);
		ADXToken.createToken(adexAddress, ALLOC_NEW_USERS);
	}

	//May be used by owner of contract to halt crowdsale and no longer except ether.
	function toggleHalt(bool _halted)
		only_owner
	{
		halted = _halted;
	}

	//constant function returns the current ADX price.
	function getPriceRate()
		constant
		returns (uint o_rate)
	{
		if (now <= publicStartTime + STAGE_ONE_TIME_END) return PRICE_STAGE_ONE;
		if (now <= publicStartTime + STAGE_TWO_TIME_END) return PRICE_STAGE_TWO;
		if (now <= publicStartTime + STAGE_THREE_TIME_END) return PRICE_STAGE_THREE;
		if (now <= publicStartTime + STAGE_FOUR_TIME_END) return PRICE_STAGE_FOUR;
		else return 0;
	}

	// Given the rate of a purchase and the remaining tokens in this tranche, it
	// will throw if the sale would take it past the limit of the tranche.
	// It executes the purchase for the appropriate amount of tokens, which
	// involves adding it to the total, minting ADX tokens and stashing the
	// ether.
	// Returns `amount` in scope as the number of ADX tokens that it will
	// purchase.
	function processPurchase(uint _rate, uint _remaining)
		internal
		returns (uint o_amount)
	{
		o_amount = SafeMath.div(SafeMath.mul(msg.value, _rate), 1 ether);
		if (o_amount > _remaining) throw;
		if (!multisigAddress.send(msg.value)) throw;
		if (!ADXToken.createToken(msg.sender, o_amount)) throw;
		ADXSold += o_amount;
		etherRaised += msg.value;
	}

	//Special Function can only be called by pre-buy and only during the pre-crowdsale period.
	//Allows the purchase of up to 125000 Ether worth of ADX Tokens.
	function preBuy()
		payable
		is_pre_crowdfund_period
		only_prebuy
		is_not_halted
	{
		uint amount = processPurchase(PRICE_PREBUY, PREBUY_PORTION_MAX - prebuyPortionTotal);
		prebuyPortionTotal += amount;
		PreBuy(amount);
	}

	//Default function called by sending Ether to this address with no arguments.
	//Results in creation of new ADX Tokens if transaction would not exceed hard limit of ADX Token.
	function()
		payable
		is_crowdfund_period
		is_not_halted
	{
		uint amount = processPurchase(getPriceRate(), ALLOC_CROWDSALE - ADXSold);
		Buy(msg.sender, amount);
	}

	//failsafe drain
	function drain()
		only_owner
	{
		if (!ownerAddress.send(this.balance)) throw;
	}
}