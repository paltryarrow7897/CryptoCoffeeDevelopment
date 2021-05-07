/* Main contract for CryptoCoffee. *******************
** Users buy custom ERC20 tokens for ETH. ************
** Use tokens to buy ingredients for further processes.
** Use ingredients to make new NFTs. *****************/

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';                                // ERC20
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol';         // ERC721
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';          // ERC721
import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';                            // ERC1155
import '@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol';                    // ERC1155
import '@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol';                 // ERC1155
import '@openzeppelin/contracts/access/Ownable.sol';                                    // Ownable right now. Add Access Control.
import '@openzeppelin/contracts/utils/Counters.sol';


contract CryptoCoffee is ERC1155Holder, ERC721URIStorage, Ownable {
    IERC20 private _token;
    IERC721Enumerable private _ierc721Enumerable;
    IERC1155 private _IERC1155token;
    
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    
    constructor(IERC20 ERC20Token, IERC1155 ERC1155Token) ERC721('CryptoCoffee', 'CRPTCF') {
    // @param ERC20Token: ERC20 Contract Address.
    // @param ERC1155Token: ERC1155 Contract Address.
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
    
    modifier onlySeller(uint256 _tokenId) {
        require(_exists(_tokenId));
        require(_isApprovedOrOwner(msg.sender, _tokenId));
        _;
    }
    
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC1155Receiver) returns (bool) {
         return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }
    
    function buyRicheduToken() external payable {
    // @param msg.value: Enter wei to get ERC20 tokens.
        require(msg.value > 0);
        require(_token.balanceOf(address(this)) >= msg.value);
        _token.transfer(msg.sender, (10**18)*msg.value);
    }
    
    function sellRicheduToken(uint256 _amount) external {
    // @param _amount: number of ERC20 tokens to get wei.
        require(_amount > 0);
        require(_token.allowance(msg.sender, address(this)) >= (10**18)*_amount);
        _token.transferFrom(msg.sender, address(this), (10**18)*_amount);
        payable(msg.sender).transfer(_amount);
    }
    
    function buyIngredients(uint256[] memory _ingredientIds, uint256[] memory _amounts, uint256[] memory _prices) external {
    // @param _ingredientIds: array of ingredient IDs.
    // @param _amounts: arrary of quantities of ingredients.
    // @param _prices: array of prices of ingredients after multiplying with quantities.
        require(_ingredientIds.length != 0);
        require((_ingredientIds.length == _amounts.length) && (_ingredientIds.length == _prices.length));
        
        if (_ingredientIds.length == 1) {
        // for one ingredient.
            require(_token.allowance(msg.sender, address(this)) >= (10**18)*_prices[0], "Check allowance.");
            require(_IERC1155token.balanceOf(address(this), _ingredientIds[0]) >= _amounts[0], "Not enough inventory.");
            _IERC1155token.safeTransferFrom(address(this), msg.sender, _ingredientIds[0], _amounts[0], "");
            _token.transferFrom(msg.sender, address(this), (10**18)*_prices[0]);
        }
        
        else {
        // for more than one ingredient.
            uint256 len = _ingredientIds.length;
            uint256 totalPrice = 0;
            for (uint256 i = 0; i < len; i++) {
                require(_IERC1155token.balanceOf(address(this), _ingredientIds[i]) >= _amounts[i], "Not enough inventory.");
                totalPrice = totalPrice + _prices[i];
            }
            require(_token.allowance(msg.sender, address(this)) >= (10**18)*totalPrice, "Check allowance.");
            _IERC1155token.safeBatchTransferFrom(address(this), msg.sender, _ingredientIds, _amounts, "");
            _token.transferFrom(msg.sender, address(this), (10**18)*totalPrice);
        }
    }
    
    function mintNFT(string memory _hash, string memory _metadata, uint256 _mintingCost, uint256 userPays) external {
        require(hashExists[_hash] != true);
        require(_mintingCost == userPays);
        
        hashExists[_hash] = true;
        _tokenIds.increment();
        
        uint256 newTokenId = _tokenIds.current();
        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, _metadata);
        
        NFT storage nft = tokenIdToNft[newTokenId];
        nft.metadata = _metadata;
        nft.hash = _hash;
        
        tokenIdToMintingCost[newTokenId] = (10**18)*_mintingCost;
        _token.transferFrom(msg.sender, address(this), (10**18)*_mintingCost);
        tokenIdToNft[newTokenId].owner = payable(msg.sender);
        emit Transfer(address(this), msg.sender, newTokenId);
    }
    
    function setPricePutOnSale(uint _tokenId, uint128 _amount) external onlySeller(_tokenId) {
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
        uint256 mintingCost = tokenIdToMintingCost[_tokenId];
        uint256 backToUser = mintingCost - mintingCost/4;
        _token.transfer(msg.sender, backToUser);
        _burn(_tokenId);
    }
    
    function buyAtSale(uint256 _tokenId, uint256 userPays) external {
        NFT storage nft = tokenIdToNft[_tokenId];
        require(nft.onSale);
        require(nft.price == userPays);
        
        _removeSale(_tokenId);
        
        if (nft.price > 0) {
            _token.transferFrom(msg.sender, nft.owner, (10**18)*nft.price);
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
            nftList[tokenIndex] = _ierc721Enumerable.tokenOfOwnerByIndex(msg.sender, tokenIndex);
            }
        return nftList;
    }
    
    function NFT_details(uint256 _tokenId) external view onlySeller(_tokenId) returns (NFT memory) {
        return tokenIdToNft[_tokenId];
    }
}
