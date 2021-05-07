pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol';

contract RicheduERC20 is ERC20PresetFixedSupply {
    constructor() ERC20PresetFixedSupply('Richedu','RCED', 10**27, msg.sender) {}
}
