export type Networks = "Base" | "Mantle";
export type Tokens = "WETH" | "USDe" | "MNT";

export interface StrategyParams {
  brinkVault?: string;
  asset: string;
  reserve: string;
}

export const STRATEGY_PARAMS: { readonly [key in Tokens]?: StrategyParams[] } =
  {
    WETH: [
      {
        asset: "0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111",
        reserve: "0x9CdF3c151BE88921544902088fdb54DDf08431d1",
      },
      {
        asset: "0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111",
        reserve: "0xd9a41322336133f2b026a65F2426647BD0Bf690C",
      },
      {
        asset: "0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111",
        reserve: "0x9f2eb80B3c49A5037Fa97d9Ff85CdE1cE45A7fa0",
      },
      {
        asset: "0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111",
        reserve: "0xeaFF9A5F8676D20F5F1C391902d9584C1b6f33f5",
      },
    ],
    MNT: [
      {
        asset: "0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8",
        reserve: "0x256eCC6C2b013BFc8e5Af0AD9DF8ebd10122d018",
      },
      {
        asset: "0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8",
        reserve: "0x5CAd26932A8D17Ba0540EeeCb3ABAdf7722DA9a0",
      },
    ],
    USDe: [
      {
        asset: "0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34",
        reserve: "0xA9c90b947a45E70451a9C16a8D5BeC2F855DbD1d",
      },
      {
        asset: "0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34",
        reserve: "0xA11A13DE301C3f17c3892786720179750a25450A",
      },
      {
        asset: "0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34",
        reserve: "0xEE50fb458a41C628E970657e6d0f01728c64545D",
      },
      {
        asset: "0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34",
        reserve: "0x42C5EbFD934923Cc2aB6a3FD91A0d92B6064DFBc",
      },
      {
        asset: "0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34",
        reserve: "0xecce86d3D3f1b33Fe34794708B7074CDe4aBe9d4",
      },
    ],
  };
