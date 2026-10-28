import * as vscode from “vscode”;

export function activate(context: vscode.ExtensionContext) {
const createPackage = vscode.commands.registerCommand(
“bacus.createPackage”,
async () => {
const name = await vscode.window.showInputBox({
prompt: “Package name / Nombre del paquete”,
placeHolder: “mi-paquete”,
validateInput: (value) =>
/^[a-zA-Z0-9]*$/.test(value)
? null
: “Use letters, numbers, dots, underscores or hyphens.”
});

  if (!name) return;
  const folder = await vscode.window.showOpenDialog({
    canSelectFiles: false,
    canSelectFolders: true,
    canSelectMany: false,
    openLabel: "Create package here / Crear paquete aquí"
  });
  if (!folder?.[0]) return;
  const root = vscode.Uri.joinPath(folder[0], name);
  await vscode.workspace.fs.createDirectory(root);
  const manifest = [
    `package_name=${name}`,
    "version=0.1.0",
    "description=New Bacus package",
    "target_os=any",
    "target_arch=any",
    "payload_format=raw-v1",
    "entrypoint=",
    "file_count=0",
    ""
  ].join("\n");
  await vscode.workspace.fs.writeFile(
    vscode.Uri.joinPath(root, "PACKAGE.bpmanifest"),
    new TextEncoder().encode(manifest)
  );
  const readme = [
    "# " + name,
    "",
    "Bacus package project / Proyecto de paquete Bacus",
    "",
    "Edit PACKAGE.bpmanifest and add your application files.",
    "Editá PACKAGE.bpmanifest y agregá los archivos de tu aplicación.",
    ""
  ].join("\n");
  await vscode.workspace.fs.writeFile(
    vscode.Uri.joinPath(root, "README.md"),
    new TextEncoder().encode(readme)
  );
  const document = await vscode.workspace.openTextDocument(
    vscode.Uri.joinPath(root, "PACKAGE.bpmanifest")
  );
  await vscode.window.showTextDocument(document);
  vscode.window.showInformationMessage(
    `Bacus: package project created / proyecto creado: ${name}`
  );
}

);

const validatePackage = vscode.commands.registerCommand(
“bacus.validatePackage”,
async () => {
const editor = vscode.window.activeTextEditor;
if (!editor) {
vscode.window.showWarningMessage(
“Open a package manifest first / Abrí primero el manifiesto.”
);
return;
}

  const text = editor.document.getText();
  const required = [
    "package_name",
    "version",
    "description",
    "target_os",
    "target_arch",
    "payload_format",
    "entrypoint",
    "file_count"
  ];
  const missing = required.filter(
    (key) => !new RegExp("^" + key + "=", "m").test(text)
  );
  if (missing.length) {
    vscode.window.showErrorMessage(
      "Missing fields / Campos faltantes: " + missing.join(", ")
    );
    return;
  }
  vscode.window.showInformationMessage(
    "Required fields found / Se encontraron los campos obligatorios."
  );
}

);

const inspectPackage = vscode.commands.registerCommand(
“bacus.inspectPackage”,
async () => {
const file = await vscode.window.showOpenDialog({
canSelectFiles: true,
canSelectFolders: false,
canSelectMany: false,
filters: { “Bacus packages”: [“bp”] }
});

  if (!file?.[0]) return;
  const stat = await vscode.workspace.fs.stat(file[0]);
  vscode.window.showInformationMessage(
    `File / Archivo: ${file[0].path.split("/").pop()} — ${stat.size} bytes`
  );
}

);

context.subscriptions.push(
createPackage,
validatePackage,
inspectPackage
);
}

export function deactivate() {}