pragma solidity ^0.6.3;
pragma experimental ABIEncoderV2;
// PostOffice allows creation of batches and top-up. TODO: price change
contract PostOffice {

    //TODO: make changeable, or part of batch
    uint256 redundancy;

    //TODO: optimize struct space
    struct Batch {
        uint256 blockHeight; // blockHeight when batch was registered (or changed? TODO)
        uint256 depth; // the depth of the batch, which should be deeper than the depth of Swarm (see StorageRegistry)
        /**
          the maximumPrice a node wants to pay for his batch. If maximumPrice < node's minimumPrize (see StorageRegistry),
          node is not allowed to earn income on batch. A node is allowed to earn income if he is within the
          R cheapest nodes from the R * A closest nodes around the chunks. A is a constant (e.g. 2) and set by the StoragePayments contract (??)
        **/
        uint256 maximumPrice;
    }

    // keeps track of the amount of payments that were made into this batch
    mapping(bytes32 => uint256[]) paymentsMade;

    // keeps count of the number of batches created by the node. A node may have multiple active batches at any time. The latest batch can be accessed by batchesCreated - 1
    mapping(address => uint256) batchesCreated;

    // maps the batchID to a Batch. The latest entry in the array is valid.  A batchID is the keccak256 hash of owner and batchesCreated (see function getBatchID)
    mapping(bytes32 => Batch[]) public batchRegistry;

    constructor(uint256 _redundancy) public {
        redundancy = _redundancy;
    }
 
    // create a batch and update paymentsMade (if any payment is included). Note: a batch is not valid if it doesn't contain a payment
    function createBatch(uint64 depth, uint136 maximumPrice) public payable {
        bytes32 batchID = getBatchID(msg.sender, batchesCreated[msg.sender]);
        batchRegistry[batchID].push(Batch(uint56(block.number), depth, maximumPrice));
        if(msg.value != 0) {
            paymentsMade[batchID].push(msg.value);
        }
        batchesCreated[msg.sender] += 1;
        // emit event
    }

    // get the batchID of the batchesCreated - 1 batch that was created by the owner.
    function getBatchID(address owner, uint256 _batchesCreated) public pure returns(bytes32) {
        return keccak256(abi.encodePacked(owner, _batchesCreated));
    }

    // anybody can top up a batch. Previously emptied batches can be filled again and can even be re-stamped (note: it can't be 100% gauaranteed that all "old" chunks disappeared in the network)
    function topUpBatch(bytes32 batchID) public payable {
        require(msg.value != 0);
        paymentsMade[batchID].push(msg.value);
    }
}