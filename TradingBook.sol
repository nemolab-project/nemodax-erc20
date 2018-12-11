// ver 0.0.1.i
pragma solidity ^0.4.25;


import "./TokenERC20.sol";
import "github.com/Arachnid/solidity-stringutils/strings.sol";

contract TradingBook is Pausable {
    using strings for *;

    struct Deal {
        string dealNo;
        string price;
        string buyer;
        string seller;
    }

    Deal[] private arrDeals;

    function recordDeal(string _dealNo, string _price, string _buyer, string _seller) onlyOwner external {
        Deal memory newData = Deal(_dealNo, _price, _buyer, _seller);
        arrDeals.push(newData);
    }

    function getNumberOfTrading() external view returns(uint ret){
        ret = arrDeals.length;
        return ret;
    }

    function getDeals() external view returns(string, uint length) {
        string memory str;

        for(uint i=0; i<arrDeals.length; i++) {

            if(i==0)
                str = "[{".toSlice().concat("\"dealNo\":\"".toSlice());
            else
                str = str.toSlice().concat(",{\"dealNo\":\"".toSlice());

            str = str.toSlice().concat(arrDeals[i].dealNo.toSlice());

            str = str.toSlice().concat("\",\"price\":\"".toSlice());
            str = str.toSlice().concat(arrDeals[i].price.toSlice());

            str = str.toSlice().concat("\",\"buyer\":\"".toSlice());
            str = str.toSlice().concat(arrDeals[i].buyer.toSlice());

            str = str.toSlice().concat("\",\"seller\":\"".toSlice());
            str = str.toSlice().concat(arrDeals[i].seller.toSlice());

            str = str.toSlice().concat("\"}".toSlice());


            if(i == arrDeals.length-1){
                str = str.toSlice().concat("]".toSlice());
                length = bytes(str).length;
            }
        }
        return (str, length);
    }
}
