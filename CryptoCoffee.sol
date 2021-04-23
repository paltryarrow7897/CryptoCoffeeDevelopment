pragma solidity >=0.6.4 <0.9.0;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/utils/Counters.sol';

contract CryptoCoffee is ERC721URIStorage {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;
  
  constructor() ERC721('Token', 'NFT') {}
  
  event newNFTminted(address owner, uint256 newTokenId);
  event nftPriceSet(uint256 tokenId, uint256 amount);
//  event Purchase(address buyer, uint256 tokenId, uint256 amount);
  event SaleSuccessful(uint256 tokenId, uint256 price, address buyer);
  
  struct NFT {
    string metadata;
    string asset;
    string hash;
    }
    
  struct Sale {
    address payable seller;
    uint128 price;
    bool onSale;
    }

  NFT[] nfts;
  
  mapping(string => uint8) hashes;
  mapping(address => NFT) collectibles;
  mapping(uint256 => address) coffeeIndexToOwner;
//  mapping(uint256 => uint256) tokenIdToPrice;
  mapping (uint256 => Sale) tokenIdToSale;


  function mint_NFT(string memory _hash, string memory _metadata) public {
    require(hashes[_hash] != 1, 'Hash has already been used!');
    hashes[_hash] = 1;
    _tokenIds.increment();
    uint256 newTokenId = _tokenIds.current();
    _safeMint(msg.sender, newTokenId);
    _setTokenURI(newTokenId, _metadata);
    emit newNFTminted(msg.sender, newTokenId);
  }
  
  function setPricePutOnSale(uint _tokenId, uint128 _amount) public {
    require(_exists(_tokenId));
    require(_isApprovedOrOwner(msg.sender, _tokenId));
    
//    tokenIdToPrice[_tokenId] = _amount;

    Sale storage sale = tokenIdToSale[_tokenId];
    sale.seller = payable(msg.sender);
    sale.price = _amount;
    sale.onSale = true;
    
    emit nftPriceSet(_tokenId, _amount);
  }
  
/*
  function sell_NFT(address _owner, address _buyer, uint256 _tokenId) public {
    require(_exists(_tokenId));
    require(_isApprovedOrOwner(_owner, _tokenId));
    require(_buyer != address(0));
  }
*/

  function transfer_NFT(address _buyer, uint _tokenId) public {
    require(_buyer != address(0));
    require(msg.sender != address(0));
    require(_exists(_tokenId));
    
//    _seller.transfer(tokenIdToPrice[_tokenId]);
//    emit Purchase(msg.sender, _tokenId, tokenIdToPrice[_tokenId]);
    
    _safeTransfer(_seller, msg.sender, _tokenId);
    emit Transfer(_seller, msg.sender, _tokenId);
  }

  function burn_NFT(address _owner, uint256 _tokenId) public {
      require(_exists(_tokenId));
      require(_isApprovedOrOwner(_owner, _tokenId));
      _burn(_tokenId);
  }
  
  function buyAtSale(uint256 _tokenId, uint256 _price) public payable {
      Sale storage sale = tokenIdToSale[_tokenId];
      require(sale.onSale);
      require(_price >= sale.price);
      
      _removeSale(_tokenId);
      
      if (sale.price > 0) {
          sale.seller.transfer(sale.price);
      }
      
      uint256 excess = _price - sale.price;
      payable(msg.sender).transfer(excess);
      
      emit SaleSuccessful(_tokenId, sale.price, msg.sender);
  }
  
  function _removeSale(uint256 _tokenId) internal {
      delete tokenIdToSale[_tokenId];
  }  

//  function penalty_on_NFT(NFT memory nft) public {}
/*
  function user_NFTs(address _owner) external view returns (NFT[]) {
      
    userBalance = balanceOf(_owner);
    if (userBalance == 0) {
        return NFT[](0);
    }
    
    else {
        for (coffeeId = 1; coffeeId <= userBalance; coffeeId++) {
            
        }
    }
    
    else {
      uint256[] memory result = new uint256[](tokenCount);
      uint256 totalCoffees = totalSupply();
      uint256 resultIndex = 0;
      uint256 coffeeId;
      
      for (coffeeId = 1; coffeeId <= totalCoffees; coffeeId++) {
        if (coffeeIndexToOwner[coffeeId] == _owner) {
                    result[resultIndex] = coffeeId;
                    resultIndex++;
                }
            }
      return result;        
        }

  }

*/
}
