pragma solidity ^0.7.6;
pragma abicoder v2;

struct Users {
    // UniswapV3Factory owner / general purpose admin
    address payable owner;
    // UniswapV3Factory fee manager
    address payable feeManager;
    // User, used to initiate calls
    address payable alice;
    // User, used as recipient
    address payable bob;
    // User, used as malicious user
    address payable charlie;
}
