// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {TicketNft} from "../nft/TicketNft.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title A sample Raffle Contract
 * @author hzd1719
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2
 */

contract Raffle is VRFConsumerBaseV2 {
    error Raffle_NotEnoughEthSent();
    error Raffle_SellingTicketsIsClosed();
    error Raffle_RaffleIsClosed();
    error Raffle_TransferFailed();

    /** Type declarations */

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_ticketPrice;
    uint256 private immutable i_interval;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    bytes32 private immutable i_gasLine;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;

    uint256 private s_lastTimeStamp;
    address private s_recentWinner;

    TicketNft ticketNft;

    /** Events */
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 tickerPrice,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLine,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_ticketPrice = tickerPrice;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLine = gasLine;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        ticketNft = new TicketNft();
    }

    function buyRaffleTicket() external payable {
        if (msg.value < i_ticketPrice) {
            revert Raffle_NotEnoughEthSent();
        }
        if (s_lastTimeStamp + i_interval < block.timestamp) {
            revert Raffle_SellingTicketsIsClosed();
        }
        //Makes migration and fron end indexing easier
        emit EnteredRaffle(msg.sender);

        ticketNft.mintnft(msg.sender);
    }

    function surpiseWinner(bytes calldata /* performData */) external {
        if (s_lastTimeStamp + i_interval >= block.timestamp) {
            revert Raffle_RaffleIsClosed();
        }
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLine,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory randomWords
    ) internal override {
        uint256 winningTokenId = randomWords[0] %
            ticketNft.getNumberOfMintedTokens();
        address winner = ticketNft.getOwnerOfToken(winningTokenId);

        s_recentWinner = winner;

        emit PickedWinner(winner);

        (bool success, ) = s_recentWinner.call{
            value: address(this).balance / 2
        }("");
        if (!success) {
            revert Raffle_TransferFailed();
        }
    }

    /** Getter Functions */

    function getEntranceFee() external view returns (uint256) {
        return i_ticketPrice;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}
