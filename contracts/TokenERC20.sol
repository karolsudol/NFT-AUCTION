// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";

contract TokenERC20 is ERC20, ERC20FlashMint {
    constructor() ERC20("TokenERC20", "KTK") {}
}
