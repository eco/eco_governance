pragma solidity ^0.8.13;    

interface IStaticMarket {
  function buy ( uint256 _amount, uint256 _expectedBuyPrice ) external;
  function buyPrice (  ) external view returns ( uint256 );
  function contractOwner (  ) external view returns ( address );
  function currentInflationMultiplier (  ) external view returns ( uint256 );
  function divideAndRoundUp ( uint256 a, uint256 b ) external pure returns ( uint256 );
  function eco (  ) external view returns ( address );
  function getCurrentBuyPrice (  ) external view returns ( uint256 );
  function getCurrentSellPrice (  ) external view returns ( uint256 );
  function isContractOwnerL2 (  ) external view returns ( bool );
  function isPriceSetterL2 (  ) external view returns ( bool );
  function messengerL2 (  ) external view returns ( address );
  function priceSetter (  ) external view returns ( address );
  function sell ( uint256 _amount, uint256 _expectedSellPrice ) external;
  function sellPrice (  ) external view returns ( uint256 );
  function setContractOwner ( address _contractOwner, bool _isContractOwnerL2 ) external;
  function setPriceSetter ( address _priceSetter, bool _isPriceSetterL2 ) external;
  function setPrices ( uint256 _buyPrice, uint256 _sellPrice ) external;
  function token (  ) external view returns ( address );
  function tokenDecimals (  ) external view returns ( uint8 );
  function transferTokens ( address _token, address _to, uint256 _amount ) external;
}
