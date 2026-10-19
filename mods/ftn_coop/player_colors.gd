extends RefCounted

const PALETTE := [Color("e8b654"),Color("65c8e0"),Color("c194f3"),Color("86d99b")]

static func for_peer(peer: int, roster: Dictionary) -> Color:
	var peers: Array = roster.keys()
	peers.sort()
	var slot := peers.find(peer)
	return PALETTE[maxi(slot,0)%4]
