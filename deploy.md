forge script script/DeploySystemAccessControl.s.sol:DeploySystemAccessControl --rpc-url https://rpc-proxy-sequoia.iqnb.com:8446

export RPC_URL="https://rpc-proxy-sequoia.iqnb.com:8446"
export DEFAULT_ADMIN_ROLE="0x0000000000000000000000000000000000000000000000000000000000000000"
export PRIVATE_KEY="0x72f25035b082fb1d8bf77035cd93aa2ea193b989209ced80957cceea6daac0b3"

cast call 0x3F01fE38fbc70b37396bB81941136193B02CB6A7 \
 "hasRole(bytes32,address)(bool)" 0x0000000000000000000000000000000000000000000000000000000000000000 0x76fF9fA884d418BED250B15aB5Aee9EED055a9CE \
 --rpc-url https://rpc-proxy-sequoia.iqnb.com:8446

forge script script/GrantRoles.s.sol:GrantRolesScript \
 --rpc-url https://rpc-proxy-sequoia.iqnb.com:8446 \
 --broadcast \
 -vvvv

cast call 0x98278B5d6E6208d3CB81484C19cE945076Bf6Efc \
"getOrganizationIdByOwner(address)(uint256)" \
0x8615491b14c77dcd3f3f23e8973046aa33f35f32 \
--rpc-url https://rpc-proxy-sequoia.iqnb.com:8446
1
lekhaihoan@YuuMini AGENTS % cast call 0x98278B5d6E6208d3CB81484C19cE945076Bf6Efc \
"getOrganizationBranches(uint256)(uint256[])" \
1 \
--rpc-url https://rpc-proxy-sequoia.iqnb.com:8446
[1, 2]
lekhaihoan@YuuMini AGENTS % cast call 0x98278B5d6E6208d3CB81484C19cE945076Bf6Efc \
"organizations(uint256)(uint256,address,bool,bool)" \
1 \
--rpc-url https://rpc-proxy-sequoia.iqnb.com:8446
1
0x8615491b14C77DCd3F3F23E8973046aA33F35F32
true
true
lekhaihoan@YuuMini AGENTS % cast call 0x98278B5d6E6208d3CB81484C19cE945076Bf6Efc \
"branches(uint256)(uint256,uint256,bool,bool)" \
1 \
--rpc-url https://rpc-proxy-sequoia.iqnb.com:8446
1
0
true
true
