// Expected parameters to work
// uint256 public tokensPerEther = 2500;
// uint256 public maxPreIcoCap = 40 ether;
// uint256 public minPreIcoCap = 10 ether;

var AuctusPreIco = artifacts.require("./AuctusPreICO.sol");

contract('AuctusPreICO', function (accounts) {

  var userTestAccount = accounts[1]

  it("Should retrieve deployed contract.", function () {
    // Check if our instance has deployed
    return AuctusPreIco.deployed().then(function (instance) {
      // Assign our contract instance for later use
      var auctusPreIco = instance
      // Pass test if we have an object returned.
      assert.isOk(auctusPreIco)
    })
  })

  it("Should not accept eth before random start block", function () {
    return AuctusPreIco.deployed().then(function (instance) {
      // try sending a 5 eth transaction from user test account to contract
      return instance.sendTransaction({ from: userTestAccount, value: web3.toWei(5, "ether") })
        .then(assert.fail)
        .catch(function (error) {
          if (invalidOpCodeException(error)) {
            assert(
              true, 'pre ico not started yet'
            )
            return instance.balanceOf.call(userTestAccount)
              .then(function (balance) {
                var agtBalance = web3.fromWei(balance).toNumber()
                assert.equal(agtBalance, 0, "wrong balance. Expected to have 0 AGT. Sending eth still not allowed")
              })
          }
          else {
            unexceptedException(error)
          }
        })
    })
  })

  it("Should not accept eth before start block -1", function () {
    return AuctusPreIco.deployed().then(function (instance) {
      return instance.preIcoStartBlock().then(function (startBlock) {
        // go to start block -2
        return goToBlockAtHeight(startBlock - 2).then(function () {
          // try sending transaction on start block - 1
          return instance.sendTransaction({ from: userTestAccount, value: web3.toWei(5, "ether") })
            .then(assert.fail)
            .catch(function (error) {

              return instance.balanceOf.call(userTestAccount)
                .then(function (balance) {
                  var agtBalance = web3.fromWei(balance).toNumber()
                  assert.equal(agtBalance, 0, "wrong balance. Expected to have 0 AGT. Sending eth still not allowed")
                })
            })
        })
      })
    })
  })

  it("Should deposit 10 eth at start block and get 25000 AGT in return", function () {
    return AuctusPreIco.deployed().then(function (instance) {
      // send a 5 eth transaction from user test account to contract
      return instance.sendTransaction({ from: userTestAccount, value: web3.toWei(10, "ether") })
        .then(function (tx) {
          // check if the transaction succeeded
          assert.isOk(tx.receipt)
          return instance.balanceOf.call(userTestAccount)
            .then(function (balance) {
              var agtBalance = web3.fromWei(balance).toNumber()
              assert.equal(agtBalance, 10 * 2500, "wrong balance. Expected to have 25000 AGT.")
            })
        })
    })
  })

  it("Should deposit 0.0023456 eth and get 5.8640 AGT in return", function () {
    return AuctusPreIco.deployed().then(function (instance) {
      // send a 5 eth transaction from user test account to contract
      return instance.sendTransaction({ from: userTestAccount, value: web3.toWei(0.0023456, "ether") })
        .then(function (tx) {
          // check if the transaction succeeded
          assert.isOk(tx.receipt)
          return instance.balanceOf.call(userTestAccount)
            .then(function (balance) {
              var agtBalance = web3.fromWei(balance).toNumber()
              assert.equal(agtBalance, 0.0023456 * 2500 + 25000, "wrong balance. Expected to have 5.846 AGT.")
            })
        })
    })
  })

  it("Sending 7.99999999 eth from a different user account", function () {
    return AuctusPreIco.deployed().then(function (instance) {
      // send a 5 eth transaction from user test account to contract
      var account = web3.eth.accounts[4]
      return instance.sendTransaction({ from: account, value: web3.toWei(7.99999999, "ether") })
        .then(function (tx) {
          // check if the transaction succeeded
          assert.isOk(tx.receipt)
          return instance.balanceOf.call(account)
            .then(function (balance) {
              var agtBalance = web3.fromWei(balance).toNumber()
              assert.equal(agtBalance, 7.99999999 * 2500, "wrong balance. Expected to have 19999.999975 AGT.")
            })
        })
    })
  })

  it("Try calling drain function before pre ico end", function () {
    return AuctusPreIco.deployed().then(function (instance) {
      // send a 5 eth transaction from user test account to contract
      return instance.drain()
        .then(assert.fail)
        .catch(function (error) {
          if (invalidOpCodeException(error)) {
            assert(
              true, 'drain not allowed yet'
            )
          }
          else {
            unexceptedException(error)
          }
        })
    })
  })

  it("User trying to call revoke function before pre ico end", function () {
    return AuctusPreIco.deployed().then(function (instance) {
      // send a 5 eth transaction from user test account to contract
      var account = web3.eth.accounts[4]
      return instance.revoke({ from: account })
        .then(assert.fail)
        .catch(function (error) {
          if (invalidOpCodeException(error)) {
            assert(
              true, 'revoke not allowed yet'
            )
          }
          else {
            unexceptedException(error)
          }
        })
    })
  })

  it("Another user sending more 30 eth going over the max pre ico cap. Last user", function () {
    return AuctusPreIco.deployed().then(function (instance) {
      // send a 5 eth transaction from user test account to contract
      var account = web3.eth.accounts[7]
      return instance.sendTransaction({ from: account, value: web3.toWei(30, "ether") })
        .then(function (tx) {
          // check if the transaction succeeded
          assert.isOk(tx.receipt)
          return instance.balanceOf.call(account)
            .then(function (balance) {
              var agtBalance = web3.fromWei(balance).toNumber()
              assert.equal(agtBalance, 30 * 2500, "wrong balance. Expected to have 75000 AGT.")
            })
        })
    })
  })

  it("User trying to send eth after max pre ico cap reached by last user", function () {
    return AuctusPreIco.deployed().then(function (instance) {
      // send a 5 eth transaction from user test account to contract
      var account = web3.eth.accounts[3]
      return instance.sendTransaction({ from: account, value: web3.toWei(3, "ether") })
        .then(assert.fail)
        .catch(function (error) {
          if (invalidOpCodeException(error)) {
            assert(
              true, 'max cap reached. Can\'t send more eth to contract.'
            )
          }
          else {
            unexceptedException(error)
          }
        })
    })
  })

  // this one should be conditional
  // it("Sending eth after ico max block limit", function () {
  //   return AuctusPreIco.deployed().then(function (instance) {
  //     // send a 5 eth transaction from user test account to contract
  //     var account = web3.eth.accounts[4]
  //     return instance.revoke({from: account})
  //       .then(assert.fail)
  //       .catch(function (error) {
  //         if (invalidOpCodeException(error)) {
  //           assert(
  //             true, 'revoke not allowed yet'
  //           )
  //         }
  //         else {
  //           unexceptedException(error)
  //         }
  //       })
  //   })
  // })

  it("User other than owner calling drain function after pre ico end", function () {
    return AuctusPreIco.deployed().then(function (instance) {
      // send a 5 eth transaction from user test account to contract
      var account = web3.eth.accounts[2]
      return instance.drain({ from: account })
        .then(assert.fail)
        .catch(function (error) {
          if (invalidOpCodeException(error)) {
            assert(
              true, 'user not allowed to call drain function'
            )
          }
          else {
            unexceptedException(error)
          }
        })
    })
  })

  it("Checking if total pre ico raised is equal to 48.00234559 eth", function () {
    return AuctusPreIco.deployed().then(function (instance) {
      // send a 5 eth transaction from user test account to contract
      return instance.weiRaised()
        .then(function (weiRaised) {
          var numberRaised = web3.fromWei(weiRaised).toNumber()
          assert.equal(numberRaised, 48.00234559, 'total raised eth not right')
        })
    })
  })


  it("Successfully calling drain function after pre ico end", function () {
    return AuctusPreIco.deployed().then(function (instance) {
      // send a 5 eth transaction from user test account to contract
      var weiBalanceOwnerBeforeDrain = web3.eth.getBalance(web3.eth.accounts[0])
      return instance.drain()
        .then(function (tx) {
          var weiBalanceAfterDrain = web3.eth.getBalance(web3.eth.accounts[0])
          var numberBalanceAfterDrain = web3.fromWei(weiBalanceAfterDrain).toNumber()
          
          assert.isAtLeast(numberBalanceAfterDrain, 147.407, 'owner balance wrong after drain')
          assert.isAtMost(numberBalanceAfterDrain, 147.408, 'owner balance wrong after drain')
        })
    })
  })


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
});