pragma solidity >=0.6.4 <0.9.0;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Counters.sol';

abstract contract ERC721Enumerable is ERC721URIStorage, IERC721Enumerable {
    
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;
    mapping(uint256 => uint256) private _ownedTokensIndex;
    uint256[] private _allTokens;
    mapping(uint256 => uint256) private _allTokensIndex;
    
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId
            || super.supportsInterface(interfaceId);
    }
    
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }
    
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }
    
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721Enumerable.totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }
    
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }
    
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }
    
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }
    
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {

        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId;
            _ownedTokensIndex[lastTokenId] = tokenIndex;
        }

        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }
    
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId;
        _allTokensIndex[lastTokenId] = tokenIndex;

        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
}

contract CryptoCoffee is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
  
    constructor() ERC721('Token', 'NFT') {} // Change name and symbol to something cryptocoffee related.
    receive() external payable {}
  
    event nftPriceSet(uint256 tokenId, uint256 amount);
    event SaleSuccessful(uint256 tokenId, uint256 price, address buyer);
    event nameChanged(uint256 tokenId, string oldName, string newName);
  
    struct NFT {
      address payable owner;
      uint128 price;
      bool onSale;
      string metadata;
      string asset;
      string hash;
    }
  
    mapping(string => bool) hashExists;
    mapping(uint256 => NFT) tokenIdToNft;
    mapping(uint256 => uint128) tokenIdToMintingCost;
    
    modifier onlySeller(uint256 _tokenId) {
        require(_exists(_tokenId));
        require(_isApprovedOrOwner(msg.sender, _tokenId));
        _;
    }

  function mintNFT(string memory _name, string memory _hash, string memory _metadata, uint128 _mintingCost) external payable {
      require(hashExists[_hash] != true);
      require(msg.value == _mintingCost);
    
      hashExists[_hash] = true;
      _tokenIds.increment();
    
      uint256 newTokenId = _tokenIds.current();
      _safeMint(msg.sender, newTokenId);
      _setTokenURI(newTokenId, _metadata);
    
      NFT storage nft = tokenIdToNft[newTokenId];
      nft.metadata = _metadata;
      nft.asset = _name;
      nft.hash = _hash;
      tokenIdToMintingCost[newTokenId] = _mintingCost;
      
      payable(address(this)).transfer(_mintingCost);
      tokenIdToNft[newTokenId].owner = payable(msg.sender);
      emit Transfer(address(this), msg.sender, newTokenId);
  }
  
  function setPricePutOnSale(uint _tokenId, uint128 _amount) external onlySeller(_tokenId) {
      NFT storage nft = tokenIdToNft[_tokenId];
      nft.owner = payable(msg.sender);
      nft.price = _amount;
      nft.onSale = true;
      emit nftPriceSet(_tokenId, _amount);
  }
  
  function burnNFT(uint256 _tokenId) external payable onlySeller(_tokenId) {
      require(tokenIdToNft[_tokenId].onSale != true);
      delete hashExists[tokenIdToNft[_tokenId].hash];
      delete tokenIdToNft[_tokenId];
      uint128 mintingCost = tokenIdToMintingCost[_tokenId];
      uint128 backToUser = mintingCost - mintingCost/4;
      payable(msg.sender).transfer(backToUser);
      _burn(_tokenId);
  }
  
  function buyAtSale(uint256 _tokenId, uint256 _price) external payable {
      NFT storage nft = tokenIdToNft[_tokenId];
      require(nft.onSale);
      require(_price >= nft.price);
      _removeSale(_tokenId);
      
      if (nft.price > 0) {
          nft.owner.transfer(nft.price);
      }
      
      uint256 excess = _price - nft.price;
      payable(msg.sender).transfer(excess);
      emit SaleSuccessful(_tokenId, nft.price, msg.sender);
      
      _transfer(tokenIdToNft[_tokenId].owner, msg.sender, _tokenId);
      emit Transfer(tokenIdToNft[_tokenId].owner, msg.sender, _tokenId);
      tokenIdToNft[_tokenId].owner = payable(msg.sender);
  }
  
  function _removeSale(uint256 _tokenId) internal {
      delete tokenIdToNft[_tokenId].onSale;
  }
  
  function stopSale(uint256 _tokenId) external onlySeller(_tokenId) {
      delete tokenIdToNft[_tokenId].onSale;
  }
  
  function changeName(uint256 _tokenId, string memory _newName) external onlySeller(_tokenId) {
      emit nameChanged(_tokenId, tokenIdToNft[_tokenId].asset, _newName);
      tokenIdToNft[_tokenId].asset = _newName;
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
}
