pragma solidity >= 0.8.0;

// SPDX-License-Identifier: UNLICENSED

import "./SafeMath.sol";

// ERC20 Token Interface.
interface IERC20 {

    // Returns Total Tokens Amount.
    function totalSupply() external view returns (uint256);

    // Returns a certain address balance of tokens.
    function balanceOf(address account) external view returns (uint256);

    // Returns allowance amount.
    function allowance(address owner, address spender) external view returns (uint256);

    // Return boolean value if a transfer can be done.
    function transfer(address recipient, uint amount) external returns (bool);

    // Returns a boolean value with a spender function.
    function approve(address spender, uint256 amount) external returns (bool);

    // Returns a boolean with transfer result using allowance.
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);



    // Event triggered on every transfer transaction.
    event Transfer(address indexed from, address indexed to, uint256 amount);

    // Event triggered when approval is triggered.
    event Approval(address indexed owner, address indexed spender, uint256 amount);

}

// Implementation of ERC20 Functions.
contract ERC20Basic is IERC20 {

    using SafeMath for uint;

    string public constant name = "ERC20Token";
    string public constant symbol = "ERCT";

    uint8 public constant decimals = 18;
    uint256 totalSupply_;

    mapping (address => uint) balances;
    mapping (address => mapping(address => uint)) allowed;

    
    constructor(uint256 _initialSupply) {
        // Sets total tokens supply.
        totalSupply_ = _initialSupply;

        balances[msg.sender] = totalSupply_;
    }


    function totalSupply() public override view returns (uint256) {
        return totalSupply_;
    }

    function increaseTotalSupply(uint _newTokensAmount) public {
        totalSupply_ += _newTokensAmount;
        balances[msg.sender] += _newTokensAmount;
    }

    function balanceOf(address _account) public override view returns (uint256) {
        return balances[_account];
    }

    function allowance(address owner, address spender) public override view returns (uint256) {
        return allowed[owner][spender];
    }

    function transfer(address recipient, uint amount) public override returns (bool) {
        require(amount >= balances[msg.sender], "Not enough balance.");

        balances[msg.sender] = balances[msg.sender].sub(amount);
        balances[recipient] = balances[recipient].add(amount);

        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint amount) public override returns (bool) {
        allowed[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint amount) public override returns (bool) {
        require(amount >= balances[sender], "Not Enough Tokens");
        require(amount >= allowed[sender][msg.sender], "Not Allowed");

        balances[sender] = balances[sender].sub(amount);
        allowed[sender][msg.sender] = allowed[sender][msg.sender].sub(amount);

        balances[recipient] = balances[recipient].add(amount);
        
        emit Transfer(sender, recipient, amount);

        return true;
    }

}