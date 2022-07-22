//SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract Jacpot is Ownable {
    using SafeMath for uint256;

    event JackpotCreated(address indexed creator, uint256 poolSize, uint256 returnRate, uint256 time);
    event JackpotClaimed(address indexed player, uint256 invested, uint256 returned, uint256 time);
    event JackpotFunded(address indexed player, uint256 amount, uint256 time);
    event JackpotFinished(uint256 id, uint256 time);

    struct Jackpot {
        uint256 id;
        uint256 minimumBet;
        uint256 maximumBet;
        uint256 poolSize;
        uint256 totalInvested;
        uint256 started;
        uint256 finished;
        uint256 [] winRates; 
        address [] winners;
        mapping (address => uint256) invested;
        mapping (address => uint256) returned;
    }

    uint256 public jackpotCounter = 0;
    mapping (uint256 => Jackpot) public jackpots;

    function createJackpot(uint256 _minimumBet, uint256 _maximumBet, uint256 _poolSize, uint256[] memory _winRates) public onlyOwner {
        // only one jackpot can be active at a time
        if (jackpotCounter != 0) {
            require(jackpots[jackpotCounter - 1].finished != 0, "Current jackpot is not finished yet");
        }
        require(_minimumBet <= _maximumBet, "Minimum bet must be less than or equal to maximum bet");
        
        // return rate is the percentage of the total bet that is returned
        // it is not stored in the jackpot, but is calculated using winRates
        uint256 returnRate;
        for (uint256 i = 0; i < _winRates.length; i++) {
            returnRate += _winRates[i];
        }
        
        // basic controls
        require(returnRate <= 100, "Return rate must be less than or equal to 100");
        require(returnRate > 0, "Return rate must be greater than 0");
        require(_poolSize > 0, "Pool size must be greater than 0");

        // create jackpot
        Jackpot storage j = jackpots[jackpotCounter];
        j.id = jackpotCounter;
        j.minimumBet = _minimumBet;
        j.maximumBet = _maximumBet;
        j.poolSize = _poolSize;
        j.totalInvested = 0;
        j.started = block.timestamp;
        j.finished = 0;
        j.winRates = _winRates;
        for(uint256 i = 0; i < _winRates.length; i++) {
            j.winners.push(address(0));
        }
        jackpotCounter++;

        // log
        emit JackpotCreated(msg.sender, j.poolSize, returnRate, block.timestamp);
    }

    function fundJackpot(address _addr) public payable {
        if (_addr == address(0)) {
            _addr = msg.sender;
        }
        // gambler invests money
        Jackpot storage j = jackpots[jackpotCounter - 1];

        // basic controls
        require(j.finished == 0, "Jackpot is finished, wait for the next one");
        require(j.poolSize >= j.totalInvested, "Pool is full");
        require(msg.value >= j.minimumBet, "Minimum bet must be greater than or equal to the amount");
        require(msg.value <= j.maximumBet, "Maximum bet must be less than or equal to the amount");

        // update numbers
        j.totalInvested += msg.value;
        j.invested[_addr] += msg.value;

        // update winners
        uint index = 0;
        uint winnerCount = 0;
        while(winnerCount < j.winRates.length && j.winners[winnerCount] != address(0) && j.winners[winnerCount] != _addr) {
            winnerCount++;
        }
        while(index < j.winRates.length && j.invested[_addr] <= j.invested[j.winners[index]] && j.winners[index] != _addr) {
            index++;
        }
        if(index < j.winRates.length) {
            for(uint256 i = index; i < winnerCount; i++) {
                j.winners[i+1] = j.winners[i];
            }
            j.winners[index] = _addr;
        }

        // log
        emit JackpotFunded(_addr, msg.value, block.timestamp);
    }

    function finishJackpot() public onlyOwner {
        // jackpot is finalized by gamble master - owner
        Jackpot storage j = jackpots[jackpotCounter - 1];

        for(uint256 i = 0; i < j.winners.length; i++) {

            // calculate the amount of money to be returned & transfer it
            uint256 amount = j.winRates[i] * j.totalInvested / 100;
            emit JackpotClaimed(j.winners[i], j.invested[j.winners[i]], amount, block.timestamp);
            j.returned[j.winners[i]] = amount;
            payable(j.winners[i]).transfer(amount);
        }

        // transfer remaining money to owner & set finished time
        payable(owner()).transfer(address(this).balance);
        j.finished = block.timestamp;
        emit JackpotFinished(j.id, block.timestamp);
    }

    function getInvested(address _addr) public view returns (uint256) {
        Jackpot storage j = jackpots[jackpotCounter - 1];
        return j.invested[_addr];
    }   

    function getCurrentWinners() public view returns (address[] memory, uint256[] memory) {
        Jackpot storage j = jackpots[jackpotCounter - 1];

        return (j.winners, j.winRates);
    }

}
