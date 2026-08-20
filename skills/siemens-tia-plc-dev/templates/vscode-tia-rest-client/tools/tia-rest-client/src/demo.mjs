import {
  closeSession,
  compilePlc,
  health,
  listBlocks,
  listPlcs,
  openSession,
  prepareGuiDownload,
  routeInfo
} from "./tiaRestClient.mjs";

function print(payload) {
  console.log(JSON.stringify(payload, null, 2));
}

async function main() {
  const action = process.argv[2] || "health";
  const projectPath = process.argv[3] || process.env.TIA_PROJECT_PATH || process.cwd();
  const plc = process.argv[4] || "PLC_1";

  switch (action) {
    case "health":
      print(await health());
      break;
    case "route-info":
      print(await routeInfo());
      break;
    case "open-session":
      print(await openSession(projectPath));
      break;
    case "close-session":
      print(await closeSession(projectPath));
      break;
    case "plcs":
      print(await listPlcs(projectPath));
      break;
    case "blocks":
      print(await listBlocks(projectPath, plc, true));
      break;
    case "compile":
      print(await compilePlc(projectPath, plc, true));
      break;
    case "prepare-download":
      print(await prepareGuiDownload(projectPath, plc));
      break;
    default:
      throw new Error(`Unknown action: ${action}`);
  }
}

main().catch((error) => {
  console.error(error.payload ? JSON.stringify(error.payload, null, 2) : error);
  process.exit(1);
});
