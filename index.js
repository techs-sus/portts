/* eslint-disable roblox-ts/no-regex */
/* eslint-disable no-undef */
/* eslint-disable roblox-ts/lua-truthiness */
import clipboard from "clipboardy";
import express from "express";
import createTunnel from "localtunnel";
import fs from "fs/promises";
import { v4 } from "uuid";

const app = express();
const port = process.env.PORT || 6969;
const regex = /-- @inject.+-- @end_inject/gms;

createTunnel({ port: port, subdomain: v4() }).then(async (tun) => {
	app.listen(port);
	console.log(`${tun.url} (copied to clipboard)`);
	const code = await fs.readFile("include/RuntimeLib.lua");
	await fs.writeFile(
		"include/RuntimeLib.lua",
		code.toString().replace(regex, `-- @inject\nlocal url = "${tun.url}"\n-- @end_inject`),
	);
	clipboard.write(tun.url).catch((e) => {});
});
