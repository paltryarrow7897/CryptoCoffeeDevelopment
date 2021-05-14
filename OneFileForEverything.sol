pragma solidity ^0.8.0;

// ERC20 files.
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol';

// ERC721 files.
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';

// ERC1155 files.
import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import '@openzeppelin/contracts/token/ERC1155/presets/ERC1155PresetMinterPauser.sol';
import '@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol';
import '@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol';

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Counters.sol';


contract CyberCafe is ERC20PresetFixedSupply {
// Deploy first.
    constructor() ERC20PresetFixedSupply('CyberCafe','CYCAFE', 10**27, msg.sender) {}
}


contract CafeIngredients is ERC1155PresetMinterPauser {
// Deploy second.
    constructor() ERC1155PresetMinterPauser("https://token-cdn-domain/{id}.json") {}
}


contract CryptoCoffee is ERC1155Holder, ERC721Enumerable, ERC721URIStorage, Ownable {
// Deploy using addresses of ERC20 and ERC1155 contracts.
    IERC20 private _token;
    IERC1155 private _IERC1155token;
    
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    
    constructor(IERC20 ERC20Token, 
                IERC1155 ERC1155Token) 
        ERC721('CryptoCoffee', 'CRPTCF') {
        _token = ERC20Token;
        _IERC1155token = ERC1155Token;
    }
    
    receive() external payable {}
    
    event nftPriceSet(uint256 tokenId, uint256 amount);
    event SaleSuccessful(uint256 tokenId, uint256 price, address buyer);
    event nameChanged(uint256 tokenId, string oldName, string newName);
    
    struct NFT {
      address owner;
      uint256 price;
      bool onSale;
      string metadata;
      string hash;
    }
    
    mapping(string => bool) hashExists;
    mapping(uint256 => NFT) tokenIdToNft;
    mapping(uint256 => uint256) tokenIdToMintingCost;
    mapping(uint256 => uint256[]) tokenIdToIngredients;
    mapping(uint256 => uint8) ingredientIdToRarity;
    mapping(uint256 => uint256) ingredientIdToPrice;
    mapping(uint256 => mapping(uint256 => uint256)) tokenIdToIngredientIdToAmount;
    
    modifier onlySeller(uint256 _tokenId) {
        require(_exists(_tokenId));
        require(_isApprovedOrOwner(msg.sender, _tokenId));
        _;
    }
    
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable, ERC1155Receiver) returns (bool) {
         return interfaceId == type(IERC721Enumerable).interfaceId 
                || interfaceId == type(IERC1155Receiver).interfaceId
                || interfaceId == type(IERC721).interfaceId
                || super.supportsInterface(interfaceId);
    }
    
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    } 
    
    function _burn(uint256 tokenId) internal virtual override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
    
    function tokenURI(uint256 tokenId) public view virtual override(ERC721URIStorage, ERC721) returns (string memory) {
        return super.tokenURI(tokenId);
    }
    
    function buyCYCAFE() external payable {
        require(msg.value > 0);
        require(_token.balanceOf(address(this)) >= msg.value);
        _token.transfer(msg.sender, msg.value);
    }
    
    function sellCYCAFE(uint256 _amount) external {
        require(_amount > 0);
        require(_token.allowance(msg.sender, address(this)) >= _amount);
        _token.transferFrom(msg.sender, address(this), _amount);
        payable(msg.sender).transfer(_amount);
    }
    
    function buyIngredients(uint256[] memory _ingredientIds, uint256[] memory _amounts, uint256[] memory _prices) external {
        require(_ingredientIds.length != 0);
        require((_ingredientIds.length == _amounts.length) && (_ingredientIds.length == _prices.length));
        
        if (_ingredientIds.length == 1) {
            require(_token.allowance(msg.sender, address(this)) >= _prices[0]);
            require(_IERC1155token.balanceOf(address(this), _ingredientIds[0]) >= _amounts[0]);
            _IERC1155token.safeTransferFrom(address(this), msg.sender, _ingredientIds[0], _amounts[0], "");
            _token.transferFrom(msg.sender, address(this), _amounts[0]*_prices[0]);
        }
        
        else {
            uint256 len = _ingredientIds.length;
            uint256 totalPrice = 0;
            for (uint256 i = 0; i < len; i++) {
                require(_IERC1155token.balanceOf(address(this), _ingredientIds[i]) >= _amounts[i]);
                totalPrice = totalPrice + _amounts[i]*_prices[i];
            }
            require(_token.allowance(msg.sender, address(this)) >= totalPrice);
            _IERC1155token.safeBatchTransferFrom(address(this), msg.sender, _ingredientIds, _amounts, "");
            _token.transferFrom(msg.sender, address(this), totalPrice);
        }
    }
    
    function mintNFT(string memory _hash, 
                    string memory _metadata, 
                    uint256 _price, 
                    uint256[] memory _ingredientIds, 
                    uint256[] memory _amounts, 
                    uint8[] memory _rarity) 
        external {
            
        require(hashExists[_hash] != true);
        hashExists[_hash] = true;
        
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        
        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, _metadata);
        _IERC1155token.safeBatchTransferFrom(msg.sender, address(this), _ingredientIds, _amounts, "");
        
        NFT storage nft = tokenIdToNft[newTokenId];
        nft.metadata = _metadata;
        nft.hash = _hash;
        
        tokenIdToMintingCost[newTokenId] = _price;
        tokenIdToIngredients[newTokenId] = _ingredientIds;
        
        for (uint256 i = 0; i < _ingredientIds.length; i++) {
            tokenIdToIngredientIdToAmount[newTokenId][_ingredientIds[i]] = _amounts[i];
            ingredientIdToRarity[_ingredientIds[i]] = _rarity[i];
        }
        
        tokenIdToNft[newTokenId].owner = msg.sender;
        emit Transfer(address(this), msg.sender, newTokenId);
    }
    
    function setPricePutOnSale(uint _tokenId, uint256 _amount) external onlySeller(_tokenId) {
        NFT storage nft = tokenIdToNft[_tokenId];
        nft.owner = msg.sender;
        nft.price = _amount;
        nft.onSale = true;
        emit nftPriceSet(_tokenId, _amount);
    }
    
    function burnNFT(uint256 _tokenId) external onlySeller(_tokenId) {
        require(tokenIdToNft[_tokenId].onSale != true);
        
        delete hashExists[tokenIdToNft[_tokenId].hash];
        delete tokenIdToNft[_tokenId];
        
        uint256[] memory ingredientIds = tokenIdToIngredients[_tokenId];
        uint256[] memory _ids;
        uint256[] memory _amounts;
        uint256 index = 0;
        
        for (uint256 i = 0; i < ingredientIds.length; i++) {
            if (ingredientIdToRarity[ingredientIds[i]] > 60) {
                _ids[index] = ingredientIds[i];
                if (tokenIdToIngredientIdToAmount[_tokenId][ingredientIds[i]] - 1 == 0) {
                    _amounts[index] = 1;
                }
                else {
                    _amounts[index] = tokenIdToIngredientIdToAmount[_tokenId][ingredientIds[i]] - 1;
                }
                index++;
            }
        }
        
        _IERC1155token.safeBatchTransferFrom(address(this), msg.sender, _ids, _amounts, "");
        _burn(_tokenId);
    }
    
    function buyAtSale(uint256 _tokenId, uint256 userPays) external {
        NFT storage nft = tokenIdToNft[_tokenId];
        require(nft.onSale);
        require(nft.price == userPays);
        
        _removeSale(_tokenId);
        
        if (nft.price > 0) {
            _token.transferFrom(msg.sender, nft.owner, nft.price);
        }
        
        emit SaleSuccessful(_tokenId, nft.price, msg.sender);
        _transfer(tokenIdToNft[_tokenId].owner, msg.sender, _tokenId);
        emit Transfer(tokenIdToNft[_tokenId].owner, msg.sender, _tokenId);
        tokenIdToNft[_tokenId].owner = msg.sender;
    }
    
    function _removeSale(uint256 _tokenId) internal {
        delete tokenIdToNft[_tokenId].onSale;
    }
    
    function stopSale(uint256 _tokenId) external onlySeller(_tokenId) {
        delete tokenIdToNft[_tokenId].onSale;
    }
    
    function giftNFT(address _giftTo, uint256 _tokenId) external onlySeller(_tokenId) {
        require(tokenIdToNft[_tokenId].onSale != true);
        safeTransferFrom(msg.sender, _giftTo, _tokenId);
        emit Transfer(msg.sender, _giftTo, _tokenId);
    }
    
    function owned_NFTs() external view returns (uint256[] memory) {
        uint256[] memory nftList = new uint256[](balanceOf(msg.sender));
        uint256 tokenIndex;
        
        for (tokenIndex = 0; tokenIndex < balanceOf(msg.sender); tokenIndex++) {
            nftList[tokenIndex] = tokenOfOwnerByIndex(msg.sender, tokenIndex);
            }
        return nftList;
    }
    
    function NFT_details(uint256 _tokenId) external view onlySeller(_tokenId) returns (NFT memory) {
        return tokenIdToNft[_tokenId];
    }
}
