pragma solidity ^0.6.3;
pragma experimental ABIEncoderV2;

// NodeRegistry registers online nodes and their prices
contract NodeRegistry {

    // the current maximum depth of Swarm. We can register maximally n^depth nodes
    // depth is NOT yet adaptable. TODO
    uint256 depth;

    // set depth during deployment.
    constructor(uint256 _depth) public {
        depth = _depth;
    }

    // HistoricalPrice records the node's minimumPrize and the blockHeight at which the variable was last changed.
    // TODO: optimize storage space in structs (keeping into account requirements from other contracts that interact with this contract)
    struct HistoricalPrice {
        uint256 blockHeight;
        uint256 minimumPrize;
    }

    // tells if slot (left border of collisionSlot) is taken. Last entry in array is current occupier. address(0) means free
    mapping(bytes32 => address[]) collisionRegistry;

    // maps owners to their HistoricalPrices. Last entry in array is current HistoricalPrice. Valid if collisionSlot is occupied by owner.
    mapping(address => HistoricalPrice[]) public nodeRegistry;

    // must be called by a node to start earning income. A node can only go online if there is a free collisionSlot for his address
    function goOnline(uint256 minimumPrize) public {
        HistoricalPrice[] storage prices = nodeRegistry[msg.sender];
        bytes32 collisionSlot = getCollisionSlot(msg.sender);
        require(!isOnline(collisionSlot, msg.sender));
        collisionRegistry[collisionSlot].push(msg.sender);
        _changePrice(prices, minimumPrize);
        // emit event
    }

    // a node can change his price when currently online
    function changePrice(uint256 minimumPrize) public {
        HistoricalPrice[] storage prices = nodeRegistry[msg.sender];
        bytes32 collisionSlot = getCollisionSlot(msg.sender);
        require(isOnline(collisionSlot, msg.sender));
        _changePrice(prices, minimumPrize);
        // emit event
    }

    // a node can go offline.
    function goOffline() public {
        HistoricalPrice[] storage prices = nodeRegistry[msg.sender];
        bytes32 collisionSlot = getCollisionSlot(msg.sender);
        require(isOnline(collisionSlot, msg.sender));
        _goOffline(prices);
    }

    // a change in price is always reflected by a push to the HistoricalPrice array for the node
    function _changePrice(HistoricalPrice[] storage prices, uint256 minimumPrize) internal {
        require(minimumPrize != 0, "NodeRegistry: 0 not a valid price");
        prices.push(HistoricalPrice(uint56(block.number), minimumPrize));
    }

    // going offline is reflected by a push to the HistoricalPrice array (with price == 0) and a de-registration on the collisionRegistry.
    // TODO: figure out if the push to the HistoricalPrice array is needed (push to the collisionRegistry might be enough)
    function _goOffline(HistoricalPrice[] storage prices) internal {
        prices.push(HistoricalPrice(uint56(block.number), 0));
        collisionRegistry[getCollisionSlot(msg.sender)].push(address(0));
    }

    // tells in which collision slot a certain address falls
    function getCollisionSlot(address node) public view returns(bytes32) {
        return bytes32(uint256(node) << 96) & shiftLeft(bytes32(2 ** depth - 1), 256 - depth);
    }

    // helper function, doing a n-bitwise shift on a
    function shiftLeft(bytes32 a, uint256 n) public pure returns (bytes32) {
        uint256 shifted = uint256(a) * 2 ** n;
        return bytes32(shifted);
    }

    // tells if a node is online, by looking at the collisionRegistry
    // TODO: function doesn't look yet at the information that is available in the HistoricalPrice array.
    function isOnline(bytes32 collisionSlot, address node) public view returns(bool) {
        return collisionRegistry[collisionSlot][collisionRegistry[collisionSlot].length] == node;
    }
}