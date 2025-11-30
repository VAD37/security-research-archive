# @version ^0.3.7

owner: public(address)

@external
def __init__():
    self.owner = msg.sender
