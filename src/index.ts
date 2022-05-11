// test lib to see what rbxts will emit in compilation

import h from "./mod";
import {t} from "@rbxts/t"

print(t.Color3([1,2,3]));

const promisetest = async () => {
	const p = new Promise((r) => {
		r("h");
	});
	await p;
};

promisetest()
print(h);

export {};
