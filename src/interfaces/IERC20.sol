// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title ERC20 Token Interface
 * @dev Standard interface for ERC20 tokens
 */
interface IERC20 {
    /**
     * @dev Returns the name of the token
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals of the token
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Returns the total token supply
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the balance of the specified account
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Returns the remaining allowance that spender can use from owner
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Transfers tokens to the specified address
     * @return True if the operation succeeded
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Transfers tokens from one address to another using allowance
     * @return True if the operation succeeded
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    /**
     * @dev Sets amount as the allowance of spender over the caller's tokens
     * @return True if the operation succeeded
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Mints tokens to the specified address
     */
    function mint(address to, uint256 amount) external;

    /**
     * @dev Emitted when tokens are transferred
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when allowance is set
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
