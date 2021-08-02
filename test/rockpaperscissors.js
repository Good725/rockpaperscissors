const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("RockPaperScissors", function() {

    let owner;
    let user1;
    let user2;
    let user3;
    let RockPaperScissorsContract;

    beforeEach(async function () {
        [owner, user1, user2, user3] = await ethers.getSigners();
        const RockPaperScissors = await ethers.getContractFactory("RockPaperScissors");
        RockPaperScissorsContract = await RockPaperScissors.deploy();
        await RockPaperScissorsContract.deployed();
    });

    describe("Set prices to play", function () {
        let price1 = ethers.utils.parseEther("1");
        let price2 = ethers.utils.parseEther("2");
        let price3 = ethers.utils.parseEther("3");
        describe("Success", function () {
            beforeEach(async function () {
                await RockPaperScissorsContract.connect(owner).setPrices([price1, price2, price3]);
            });
            it("Should be correct prices", async function () {
                expect(await RockPaperScissorsContract.priceToPlay(0)).to.equal(price1);
                expect(await RockPaperScissorsContract.priceToPlay(1)).to.equal(price2);
                expect(await RockPaperScissorsContract.priceToPlay(2)).to.equal(price3);
            });
        });
        describe("Fail", function () {
            it("Should fail if no owner trying to set prices", async function () {
                await expect(RockPaperScissorsContract.connect(user1).setPrices([price1, price2, price3])).to.be.revertedWith("!owner");
            });
        })
    });

    describe("Bet", function () {
        let price1 = ethers.utils.parseEther("1");
        let price2 = ethers.utils.parseEther("2");
        let price3 = ethers.utils.parseEther("3");
        let betAmount1 = ethers.utils.parseEther("1");
        let betAmount2 = ethers.utils.parseEther("1");
        describe("Success", function () {
            beforeEach(async function () {
                await RockPaperScissorsContract.connect(owner).setPrices([price1, price2, price3]);
                await RockPaperScissorsContract.connect(user1).bet({value: betAmount1});
                await RockPaperScissorsContract.connect(user2).bet({value: betAmount2});
            });
            it("Should change players correctly", async function () {
                expect(await RockPaperScissorsContract.playersPerPrice(betAmount1, 0)).to.equal(user1.address);
                expect(await RockPaperScissorsContract.playersPerPrice(betAmount1, 1)).to.equal(user2.address);
            });
            it("Should change players stake amount", async function () {
                expect(await RockPaperScissorsContract.stakeAmountPerUser(user1.address)).to.equal(betAmount1);
                expect(await RockPaperScissorsContract.stakeAmountPerUser(user2.address)).to.equal(betAmount2);
            });
        });
        describe("Fail", function () {
            beforeEach(async function () {
                await RockPaperScissorsContract.connect(owner).setPrices([price1, price2, price3]);
                await RockPaperScissorsContract.connect(user1).bet({value: betAmount1});
                await RockPaperScissorsContract.connect(user2).bet({value: betAmount2});
            });
            it("Should fail if the room is fill", async function () {
                let betAmount3 = ethers.utils.parseEther("1");
                await expect(RockPaperScissorsContract.connect(user3).bet({value: betAmount3})).to.be.revertedWith("the room is full");
            });
        });
    });

    describe("Play", function() {
        let price1 = ethers.utils.parseEther("1");
        let price2 = ethers.utils.parseEther("2");
        let price3 = ethers.utils.parseEther("3");
        let betAmount1 = ethers.utils.parseEther("1");
        let betAmount2 = ethers.utils.parseEther("1");
        let balance1;
        let balance2;
        beforeEach(async function () {
            balance1 = await user1.getBalance();
            balance2 = await user2.getBalance();
            await RockPaperScissorsContract.connect(owner).setPrices([price1, price2, price3]);
            await RockPaperScissorsContract.connect(user1).bet({value: betAmount1});
            await RockPaperScissorsContract.connect(user2).bet({value: betAmount2});
        });
        describe("Success", function () {
            beforeEach(async function () {
                let rock = 1;
                let paper = 2;
                await RockPaperScissorsContract.connect(user1).play(rock);
                await RockPaperScissorsContract.connect(user2).play(paper);
            });
            it("Winer should get 195% correctly(5% goes to fomo)", async function () {
                let balance1_after_play = await user1.getBalance();
                let balance2_after_play = await user2.getBalance();
                console.log("User1 balance before betting", balance1.toString());
                console.log("User1 balance after playing", balance1_after_play.toString());

                console.log("User2 balance before betting", balance2.toString());
                console.log("User2 balance after playing", balance2_after_play.toString());
            }); 
            it("Fomo balance check", async function () {
                expect(await RockPaperScissorsContract.fomoBalance()).to.equal((10**17).toString());
            });
        });
        describe("Fail", function () {
            it("Should fail if the choice is not correct", async function () {
                let choice = 4;
                await expect(RockPaperScissorsContract.connect(user1).play(choice)).to.be.revertedWith("Undefined selector");
            });
        });
    });
});
