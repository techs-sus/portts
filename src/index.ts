// test lib to see what rbxts will emit in compilation

import h from "./mod";
import net from "@rbxts/net"

const promisetest = async () => {
	const p = new Promise((r) => {
		r("h");
	});
	await p;
};

print(net)

promisetest()

print(h);

export {};
