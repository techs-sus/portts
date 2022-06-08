/* eslint-disable roblox-ts/no-regex */
/* eslint-disable no-undef */
/* eslint-disable roblox-ts/lua-truthiness */
import clipboard from "clipboardy";
import express from "express";
import createTunnel from "localtunnel";
import fs from "fs/promises";
import path from "path";
import { v4 } from "uuid";
import { fileURLToPath } from "url";

const app = express();
const port = process.env.PORT || 6969;
const regex = /-- @inject.+-- @end_inject/gms;

app.use(express.json());

app.use("/npm", express.static("node_modules"));
app.use("/src", express.static("out"));
app.use("/lib", express.static("include/RuntimeLib.lua"));

createTunnel({ port: port, subdomain: v4() }).then(async (tun) => {
	app.listen(port);
	console.log(`${tun.url} (copied to clipboard)`);
	const code = await fs.readFile("include/RuntimeLib.lua");
	await fs.writeFile(
		"include/RuntimeLib.lua",
		code.toString().replace(regex, `-- @inject\nlocal url = "${tun.url}"\n-- @end_inject`),
	);
	clipboard.write("h/" + tun.url + "/lib").catch((e) => {});
});
