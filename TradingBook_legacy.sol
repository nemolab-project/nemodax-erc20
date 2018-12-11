//v.0.0.1 Test for storing data on blockchain

pragma solidity ^0.4.25;

import "./TokenERC20.sol";

contract TradingBook is Pausable {

  // 29byte
  struct Deal {
      uint64 dealNo; // 0 ~ 1.844674407370955e19  8byte 하루에 100조건 거래일때 500년간 거래량 => 1.825 * 10^19
      uint104 price; // 0 ~ 2.028240960365167e31  13byte 10^13 * 10^18 소숫점 18자리까지 표현 가능한 코인 10조개까지 표현가능
      uint32 buyer; // 0 ~ 4294967296 42억        4byte
      uint32 seller; //                           4byte
  }

    mapping (uint256 => Deal[]) public dealsWithNo;
    mapping (uint256 => Deal[]) public dealsWithPrice;

    Deal[] public cart;

    function recordDeal(uint256 _dealNo, uint256 _price, string _buyer) onlyOwner external {
        Deal memory newData = Deal(_dealNo, _price, _buyer);

        dealsWithNo[_dealNo].push(newData);
        dealsWithPrice[_price].push(newData);
    }

    function getDealWithNo(uint256 _dealNo) view external returns (uint256 , uint256, string){
        return (dealsWithNo[_dealNo][0].dealNo, dealsWithNo[_dealNo][0].price, dealsWithNo[_dealNo][0].buyer);
    }

    function getDealWithPrice(uint256 _price) external view returns (uint256, uint256){
        uint i;
        uint length = dealsWithPrice[_price].length;

        Deal[] memory resBuf = new Deal[](length);

        for(i=0; i<length; i++) {
            resBuf[i] = dealsWithPrice[_price][i];
        }

        return (dealsWithPrice[_price][0].dealNo, dealsWithPrice[_price][0].price);
    }
    //... it might that there are more getDealwithsomething functions...

}
