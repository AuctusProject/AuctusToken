// Expected parameters to work
// uint256 public tokensPerEther = 2500;
// uint256 public maxPreIcoCap = 40 ether;
// uint256 public minPreIcoCap = 10 ether;

function goToBlockAtHeight(blockHeight) {
  var currentBlockHeight = web3.eth.blockNumber
  if (blockHeight <= currentBlockHeight) {
    return Promise.reject('can\'t go to block height. Already passed.')
  }
  return increaseBlockHeight(blockHeight - currentBlockHeight)
}

function increaseBlockHeight(increase) {
  var promises = []
  for (var i = 0; i < increase; ++i) {
    promises.push(dumbTransaction())
  }
  return Promise.all(promises)
}

function dumbTransaction() {
  return web3.eth.sendTransaction({ from: web3.eth.accounts[8], to: web3.eth.accounts[9], value: web3.toWei(0.1, "ether") })
}

function unexceptedException(error) {
  assert(false, 'Unexcepted Exception: ' + error.toString())
}

function invalidOpCodeException(error) {
  return error && error.toString().indexOf('invalid opcode') > -1
}

var AuctusPreIco = artifacts.require("./AuctusPreICO.sol");

contract('AuctusPreICO', function (accounts) {

  var userTestAccount = accounts[1]

  var contractInstance = null

  it("Should retrieve deployed contract.", function () {
    // Check if our contractInstance has deployed
    return AuctusPreIco.deployed().then(function (instance) {
      // Pass test if we have an object returned.

      contractInstance = instance
      assert.isOk(contractInstance)
    })
  })

  it("Should not accept eth before random start block", function () {
    // try sending a 5 eth transaction from user test account to contract
    return contractInstance.sendTransaction({ from: userTestAccount, value: web3.toWei(5, "ether") })
      .then(assert.fail)
      .catch(function (error) {
        assert(invalidOpCodeException(error), 'error. unexpected exception.')
        return contractInstance.balanceOf.call(userTestAccount)
          .then(function (balance) {
            var agtBalance = web3.fromWei(balance).toNumber()
            assert.equal(agtBalance, 0, "wrong balance. Expected to have 0 AGT. Sending eth still not allowed")
          })
      })
  })

  it("Should not accept eth before start block -1", function () {
    return contractInstance.preIcoStartBlock().then(function (startBlock) {
      // go to start block -2
      return goToBlockAtHeight(startBlock - 2).then(function () {
        // try sending transaction on start block - 1
        return contractInstance.sendTransaction({ from: userTestAccount, value: web3.toWei(5, "ether") })
          .then(assert.fail)
          .catch(function (error) {

            return contractInstance.balanceOf.call(userTestAccount)
              .then(function (balance) {
                var agtBalance = web3.fromWei(balance).toNumber()
                assert.equal(agtBalance, 0, "wrong balance. Expected to have 0 AGT. Sending eth still not allowed")
              })
          })
      })
    })
  })

  it("Should deposit 10 eth at start block and get 25000 AGT in return", function () {
    // send a 5 eth transaction from user test account to contract
    return contractInstance.sendTransaction({ from: userTestAccount, value: web3.toWei(10, "ether") })
      .then(function (tx) {
        // check if the transaction succeeded
        assert.isOk(tx.receipt)
        return contractInstance.balanceOf.call(userTestAccount)
          .then(function (balance) {
            var agtBalance = web3.fromWei(balance).toNumber()
            assert.equal(agtBalance, 10 * 2500, "wrong balance. Expected to have 25000 AGT.")
          })
      })
  })

  it("Should deposit 0.0023456 eth and get 5.8640 AGT in return", function () {
    // send a 5 eth transaction from user test account to contract
    return contractInstance.sendTransaction({ from: userTestAccount, value: web3.toWei(0.0023456, "ether") })
      .then(function (tx) {
        // check if the transaction succeeded
        assert.isOk(tx.receipt)
        return contractInstance.balanceOf.call(userTestAccount)
          .then(function (balance) {
            var agtBalance = web3.fromWei(balance).toNumber()
            assert.equal(agtBalance, 0.0023456 * 2500 + 25000, "wrong balance. Expected to have 5.846 AGT.")
          })
      })
  })

  it("Sending 7.99999999 eth from a different user account", function () {
    // send a 5 eth transaction from user test account to contract
    var account = web3.eth.accounts[4]
    return contractInstance.sendTransaction({ from: account, value: web3.toWei(7.99999999, "ether") })
      .then(function (tx) {
        // check if the transaction succeeded
        assert.isOk(tx.receipt)
        return contractInstance.balanceOf.call(account)
          .then(function (balance) {
            var agtBalance = web3.fromWei(balance).toNumber()
            assert.equal(agtBalance, 7.99999999 * 2500, "wrong balance. Expected to have 19999.999975 AGT.")
          })
      })
  })

  it("Try calling drain function before pre ico end", function () {
    // send a 5 eth transaction from user test account to contract
    return contractInstance.drain()
      .then(assert.fail)
      .catch(function (error) {
        assert(invalidOpCodeException(error), 'error. unexpected exception.')
      })
  })

  it("User trying to call revoke function before pre ico end", function () {
    // send a 5 eth transaction from user test account to contract
    var account = web3.eth.accounts[4]
    return contractInstance.revoke({ from: account })
      .then(assert.fail)
      .catch(function (error) {
        assert(invalidOpCodeException(error), 'error. unexpected exception.')
      })
  })

  it("Another user sending more 30 eth going over the max pre ico cap. Last user", function () {
    // send a 5 eth transaction from user test account to contract
    var account = web3.eth.accounts[7]
    return contractInstance.sendTransaction({ from: account, value: web3.toWei(30, "ether") })
      .then(function (tx) {
        // check if the transaction succeeded
        assert.isOk(tx.receipt)
        return contractInstance.balanceOf.call(account)
          .then(function (balance) {
            var agtBalance = web3.fromWei(balance).toNumber()
            assert.equal(agtBalance, 30 * 2500, "wrong balance. Expected to have 75000 AGT.")
          })
      })
  })

  it("User trying to send eth after max pre ico cap reached by last user", function () {
    // send a 5 eth transaction from user test account to contract
    var account = web3.eth.accounts[3]
    return contractInstance.sendTransaction({ from: account, value: web3.toWei(3, "ether") })
      .then(assert.fail)
      .catch(function (error) {
        assert(invalidOpCodeException(error), 'error. unexpected exception.')
      })
  })

  it("User other than owner calling drain function after pre ico end", function () {
    // send a 5 eth transaction from user test account to contract
    var account = web3.eth.accounts[2]
    return contractInstance.drain({ from: account })
      .then(assert.fail)
      .catch(function (error) {
        assert(invalidOpCodeException(error), 'error. unexpected exception.')
      })
  })

  it("Checking if total pre ico raised is equal to 48.00234559 eth", function () {
    // send a 5 eth transaction from user test account to contract
    return contractInstance.weiRaised()
      .then(function (weiRaised) {
        var numberRaised = web3.fromWei(weiRaised).toNumber()
        assert.equal(numberRaised, 48.00234559, 'total raised eth not right')
      })
  })


  it("Successfully calling drain function after pre ico end", function () {
    // send a 5 eth transaction from user test account to contract
    var weiBalanceOwnerBeforeDrain = web3.eth.getBalance(web3.eth.accounts[0])
    return contractInstance.drain()
      .then(function (tx) {
        var weiBalanceAfterDrain = web3.eth.getBalance(web3.eth.accounts[0])
        var numberBalanceAfterDrain = web3.fromWei(weiBalanceAfterDrain).toNumber()

        assert.isAtLeast(numberBalanceAfterDrain, 147.407, 'owner balance wrong after drain')
        assert.isAtMost(numberBalanceAfterDrain, 147.408, 'owner balance wrong after drain')
      })
  })

  it("User calling revoke function after pre ico end not reaching minimum cap", function () {
    return AuctusPreIco.new().then(function (instance) {
      contractInstance = instance
      var account = web3.eth.accounts[5]
      return contractInstance.sendTransaction({ from: account, value: web3.toWei(3, "ether") })
        .then(function (tx) {
          return contractInstance.preIcoEndBlock()
            .then(function (endBlock) {
              return goToBlockAtHeight(endBlock)
                .then(function () {
                  var weiBalanceBeforeRevoke = web3.eth.getBalance(account)
                  return contractInstance.revoke({ from: account })
                    .then(function () {
                      var weiBalanceAfterRevoke = web3.eth.getBalance(account)
                      assert.isAtLeast(web3.fromWei(weiBalanceAfterRevoke).toNumber(), 99.97, 'revoke failed. user should\'ve received 3 eth back')
                      assert.isAtMost(web3.fromWei(weiBalanceAfterRevoke).toNumber(), 99.99, 'revoke failed. user should\'ve received 3 eth back')
                    })
                })
            })
        })
    })
  })

  it("Try calling drain after pre ico failed", function () {
    // send a 5 eth transaction from user test account to contract
    return contractInstance.drain()
      .then(assert.fail)
      .catch(function (error) {
        assert(invalidOpCodeException(error), 'error. unexpected exception.')
      })
  })
})