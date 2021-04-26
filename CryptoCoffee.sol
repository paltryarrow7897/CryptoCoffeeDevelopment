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
  
  mapping(string => bool) hashExists;               // hash string to bool.
  mapping(uint256 => NFT) tokenIdToNft;             // token id to struct NFT.
  mapping(uint256 => address) tokenIdToOwner;       // token id to address owner.
  mapping(address => NFT) collectibles;             // owner address to struct NFT.
  mapping(uint256 => Sale) tokenIdToSale;           // token id to struct Sale.


  function mint_NFT(string memory _name, string memory _hash, string memory _metadata) public {
    require(hashExists[_hash] != true, "Hash already exists.");               // checks if NFT already exists.
    
    hashExists[_hash] = true;                                                 // set hash exists for new NFTs.
    _tokenIds.increment();                                                    // increment token id.
    uint256 newTokenId = _tokenIds.current();                                 // give token id to the NFT.
    
    _safeMint(msg.sender, newTokenId);                                        // mint new token.
    _setTokenURI(newTokenId, _metadata);                                      // set metadata for token.
    
    NFT storage nft = tokenIdToNft[newTokenId];                               // map token id to nft struct.
    nft.metadata = _metadata;                                                 // nft metadata from json.
    nft.asset = _name;                                                        // nft name from user.
    nft.hash = _hash;                                                         // nft hash.
    
    tokenIdToOwner[newTokenId] = msg.sender;                                  // map token id to its owner.
    emit newNFTminted(msg.sender, newTokenId);                                // trigger minted event.
  }
  
  function setPricePutOnSale(uint _tokenId, uint128 _amount) public {
  
  // we want the seller to set a price on his NFT and put it on sale.
  // if he doesn't set a price, the NFT is not sellable.
  // right now, as soon as seller sets price, NFT is added to sale.
  // it can changed by giving seller an option to put on sale right now or schedule for later.
  
    require(_exists(_tokenId), "Token ID does not exist.");
    require(_isApprovedOrOwner(msg.sender, _tokenId), "You do not have permission.");

    Sale storage sale = tokenIdToSale[_tokenId];
    sale.seller = payable(msg.sender);        // seller address.
    sale.price = _amount;                     // seller sets NFT price.
    sale.onSale = true;                       // seller turns on put on sale. 
    
    // if we want to allow the owner to set a price but not put on sale right now, remove sale.onSale from this function,
    // and add it to a new function. this will, however count as one more transaction the user will have to pay for.
    
    emit nftPriceSet(_tokenId, _amount);      // trigger price set event.
  }

  function burn_NFT(address _owner, uint256 _tokenId) public {
  
  // this burns NFT but doesn't give back ingredients.
  
      require(_exists(_tokenId), "Token ID does not exist.");                                     // NFT to burn must exist.
      require(_isApprovedOrOwner(_owner, _tokenId), "You do not have permission.");               // Only owner or approved can burn NFT.
      require(tokenIdToSale[_tokenId].onSale != true, "Can not burn if token is on sale.");       // NFT must not be on sale when burned.
      
      delete hashExists[tokenIdToNft[_tokenId].hash];     // delete hash so in future, same NFT can be minted again. Can be removed if burned NFT should never be minted again.
      _burn(_tokenId);                                    // burn NFT after deleting its hash.
  }
  
  function buyAtSale(uint256 _tokenId, uint256 _price) public payable {
  
  // I tried copying cryptokitties auction contract. what it should do is allow buyer to transfer ether to seller's address. 
  // if buyer's price is more than seller's price, refund is issued and the sale for that NFT ends so that no other buyer
  // can accidentally pay for the sold NFT.
  
  // Edit: buyAtSale now automatically transfers token from seller address to buyer address. No separate transfer function needed any more.
  
      Sale storage sale = tokenIdToSale[_tokenId];
      require(sale.onSale, "Token not on sale.");                                     // token must be on sale.
      require(_price >= sale.price, "You are paying less than seller's price.");      // buyer must pay at least what seller asks for.
      
      _removeSale(_tokenId);
      
      if (sale.price > 0) {                   // if seller asks for more than 0 wei,
          sale.seller.transfer(sale.price);   // transfer wei to seller.
      }
      
      uint256 excess = _price - sale.price;   // check if buyer is paying extra amount.
      payable(msg.sender).transfer(excess);   // send back excess amount.
      emit SaleSuccessful(_tokenId, sale.price, msg.sender);
      
      _transfer(tokenIdToOwner[_tokenId], msg.sender, _tokenId);      // transfer ownership after successful sale.
      emit Transfer(tokenIdToOwner[_tokenId], msg.sender, _tokenId);
      
      tokenIdToOwner[_tokenId] = msg.sender;  // map token id to its new owner.
  }

  function _removeSale(uint256 _tokenId) internal {
  // internal function to avoid a different buyer to accidentally pay for a sold NFT.
     delete tokenIdToSale[_tokenId];
  }
  
  function stopSale(uint256 _tokenId) public {
  // public function to allow owner to manually remove NFT from sale.
  // can be executed if owner wants to change selling price or burn NFT or does not want to sell an NFT any more.
     require(_isApprovedOrOwner(msg.sender, _tokenId), "You do not have permission.");
     delete tokenIdToSale[_tokenId];
  }

//  function penalty_on_NFT(NFT memory nft) public {}
//  penalty on NFT not implemented.
 
/*
  user_NFTs not done yet.
  ERC721Enumerable extension contract will be used, from that, tokenOfOwnerByIndex function is of importance.
  I could not use that because of errors generated if used with ERC721URIStorage extension contract.

  function owned_NFTs() external view returns (uint256[] memory) {
      uint256[] memory nftList;
      uint listIndex = 0;
      uint256 tokenIndex;
      
      if (balanceOf(msg.sender) == 0) {
        return nftList[](0);     
      }
      
      else {
          for (tokenIndex = 1; tokenIndex <= balanceOf(msg.sender); tokenIndex++) {
              nftList[listIndex] = tokenOfOwnerByIndex(msg.sender, tokenIndex);
              listIndex++;
          }
          return nftList;
      }
  }
*/  
}
