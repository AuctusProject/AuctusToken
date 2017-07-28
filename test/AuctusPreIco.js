var AuctusPreIco = artifacts.require("./AuctusPreICO.sol");

contract('AuctusPreICO', function (accounts) {

  it("Should retrive deployed contract.", function () {
    // Check if our instance has deployed
    return AuctusPreIco.deployed().then(function (instance) {
      // Assign our contract instance for later use
      var auctusPreIco = instance
      // Pass test if we have an object returned.
      assert.isOk(auctusPreIco)
      // Tell Mocha move on to the next sequential test.
    })
  })

  it("Should deposit 5 eth and get 12500 AGT in return", function () {
    return AuctusPreIco.deployed().then(function (instance) {
      // send a transaction from account 3 from 5 eth to contract
      return instance.sendTransaction({from: accounts[3],value: web3.toWei(5, "ether")}).then(function (tx) {
        // check if the transaction succeeded
        assert.isOk(tx.receipt)
        return instance.balanceOf.call(accounts[3]).then(function (balance) {
          var agtBalance = web3.fromWei(balance).toNumber()
          assert.equal(agtBalance, 5 * 2500, "wrong balance. Expected to have 12500 AGT.")
        })
      })
    })
  })
});
