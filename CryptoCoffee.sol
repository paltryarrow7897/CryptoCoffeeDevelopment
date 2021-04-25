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
  mapping (uint256 => Sale) tokenIdToSale;


  function mint_NFT(string memory _hash, string memory _metadata) public {
    require(hashes[_hash] != 1);
    hashes[_hash] = 1;
    _tokenIds.increment();
    uint256 newTokenId = _tokenIds.current();
    _safeMint(msg.sender, newTokenId);
    _setTokenURI(newTokenId, _metadata);
    emit newNFTminted(msg.sender, newTokenId);
  }
  
  function setPricePutOnSale(uint _tokenId, uint128 _amount) public {
  
  // we want the seller to set a price on his NFT and put it on sale.
  // if he doesn't set a price, the NFT is not sellable.
  // right now, as soon as seller sets price, NFT is added to sale.
  // it can changed by giving seller an option to put on sale right now or schedule for later.
  
    require(_exists(_tokenId));
    require(_isApprovedOrOwner(msg.sender, _tokenId));

    Sale storage sale = tokenIdToSale[_tokenId];
    sale.seller = payable(msg.sender); // seller address
    sale.price = _amount; // seller sets NFT price
    sale.onSale = true; // seller turns on put on sale 
    
    emit nftPriceSet(_tokenId, _amount);
  }

  function transfer_NFT(address _buyer, uint _tokenId) public {
  
  // this needs editing.
  // this function should be called by the seller only.
  // seller transfers NFT after confirming payment.
  
    require(_buyer != address(0));
    require(msg.sender != address(0));
    require(_exists(_tokenId));
    
    safeTransferFrom(msg.sender, _buyer, _tokenId);
    emit Transfer(msg.sender, _buyer, _tokenId);
  }

  function burn_NFT(address _owner, uint256 _tokenId) public {
  
  // this burns NFT but doesn't give back ingredients.
  // I haven't given much time to it yet.
  // only owner can burn his NFT.
  
      require(_exists(_tokenId));
      require(_isApprovedOrOwner(_owner, _tokenId));
      _burn(_tokenId);
  }
  
  function buyAtSale(uint256 _tokenId, uint256 _price) public payable {
  
  // I tried copying cryptokitties auction contract.
  // what it should do is allow buyer to transfer ether to seller's
  // address. if buyer's price is more than seller's price, refund 
  // is issued and the sale for that NFT ends so that no other buyer
  // can accidentally pay for the sold NFT.
  
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
//  penalty on NFT not implemented.

/* 

  user_NFTs not done yet. there is a function in cryptokitties which
  does the same thing. I was trying to copy and modify that.

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
