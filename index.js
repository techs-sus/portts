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
const port = process.env.PORT || 3000;
const regex = /TS\.import\(script, ?script, ?['"]([a-zA-Z0-9_]+)['"]\)/gm

async function link(file) {
  const contents = await fs.readFile(file)
}
