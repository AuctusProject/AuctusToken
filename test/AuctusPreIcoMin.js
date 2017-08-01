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

  it("Testing owner drain after min ico reached successfully", function () {
    return AuctusPreIco.deployed().then(function (contractInstance) {
      // send a 5 eth transaction from user test account to contract
      return contractInstance.preIcoStartBlock()
        .then(function (startBlock) {
          return contractInstance.preIcoEndBlock()
            .then(function (endBlock) {
              return goToBlockAtHeight(startBlock)
                .then(function () {
                  var account = web3.eth.accounts[2]
                  return contractInstance.minPreIcoCap()
                    .then(function (minPreIcoCap) {
                      return contractInstance.sendTransaction({ from: account, value: minPreIcoCap })
                        .then(function () {
                          return goToBlockAtHeight(endBlock).then(function () {
                            return contractInstance.drain()
                              .then(function () {

                                var weiBalanceAfterDrain = web3.eth.getBalance(web3.eth.accounts[0])
                                var numberBalanceAfterDrain = web3.fromWei(weiBalanceAfterDrain).toNumber()

                                assert.isAtLeast(numberBalanceAfterDrain, 100 + web3.fromWei(minPreIcoCap).toNumber() - 1, 'owner balance wrong after drain')
                                assert.isAtMost(numberBalanceAfterDrain, 100 + web3.fromWei(minPreIcoCap).toNumber() + 1, 'owner balance wrong after drain')

                              })
                          })
                        })
                    })
                })
            })
        })
    })

    it("User trying to send eth after ico ended and drained", function () {
      // send a 5 eth transaction from user test account to contract
      var account = web3.eth.accounts[3]
      return contractInstance.sendTransaction({ from: account, value: web3.toWei(3, "ether") })
        .then(assert.fail)
        .catch(function (error) {
          assert(invalidOpCodeException(error), 'error. unexpected exception.')
        })
    })
  })
})