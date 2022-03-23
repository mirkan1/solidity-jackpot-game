//SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract Jacpot is Ownable {
    using SafeMath for uint;

    event JackpotCreated(address indexed creator, uint256 amount, uint256 returnRate, uint256 time);
    event JackpotClaimed(address indexed player, uint256 invested, uint256 returned, uint256 time);
    event JackpotFunded(address indexed player, uint256 amount, uint256 time);
    event JackpotFinished(uint256 id, uint256 time, address[] indexed winners, uint256[] amounts);

    struct Jackpot {
        uint256 id;
        uint256 minimumBet;
        uint256 maximumBet;
        uint256 poolSize;
        uint256 totalInvested;
        uint256 started;
        uint256 finished;
        mapping (address => uint256) invested;
        mapping (address => uint256) returned;
    }

    uint256 public jackpotCounter = 0;
    mapping (uint256 => Jackpot) public jackpots;

    function createJackpot(uint256 _minimumBet, uint256 _maximumBet, uint256 _poolSize, uint256 _returnRate) public payable {
        require(_minimumBet <= _maximumBet, "Minimum bet must be less than or equal to maximum bet");
        require(_returnRate <= 100, "Return rate must be less than or equal to 100");
        require(_returnRate > 0, "Return rate must be greater than 0");
        require(_poolSize > 0, "Pool size must be greater than 0");

        Jackpot storage j = jackpots[jackpotCounter];
        j.id = jackpotCounter;
        j.minimumBet = _minimumBet;
        j.maximumBet = _maximumBet;
        j.poolSize = _poolSize;
        j.totalInvested = 0;
        j.started = block.timestamp;

        jackpotCounter++;

        emit JackpotCreated(msg.sender, msg.value, _returnRate, block.timestamp);
    }

    function fundJackpot() public payable {
        require(msg.value >= jackpots[jackpotCounter - 1].minimumBet, "Minimum bet must be greater than or equal to the amount");
        require(msg.value <= jackpots[jackpotCounter - 1].maximumBet, "Maximum bet must be less than or equal to the amount");

        jackpots[jackpotCounter-1].totalInvested += msg.value;
        jackpots[jackpotCounter-1].invested[msg.sender] += msg.value;

        emit JackpotFunded(msg.sender, msg.value, block.timestamp);
    }
}