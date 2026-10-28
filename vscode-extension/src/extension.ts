
import * as vscode from "vscode";
import * as path from "path";

const MAGIC = Buffer.from("BACUSBP1", "ascii");

type PackageEntry = {
  path: string;
  size: number;
};

function joinBytes(parts: Uint8Array[]): Buffer {
  return Buffer.concat(parts.map(part => Buffer.from(part)));
}

function safeRelativePath(value: string): boolean {
  if (!value || value.includes("\\") || value.includes("\0")) {
    return false;
  }

  if (value.startsWith("/") || /^[a-zA-Z]:/.test(value)) {
    return false;
  }

  return !value.split("/").some(
    part => part === ".." || part === "." || part === ""
  );
}

function manifestValue(text: string, key: string): string | undefined {
  const line = text.split(/\r?\n/).find(
    item => item.startsWith(key + "=")
  );

  return line?.slice(key.length + 1).trim();
}

async function readProjectFiles(
  root: vscode.Uri,
  relative = ""
): Promise<{ path: string; data: Buffer }[]> {
  const directory = relative
    ? vscode.Uri.joinPath(root, ...relative.split("/"))
    : root;

  const result: { path: string; data: Buffer }[] = [];
  const children = await vscode.workspace.fs.readDirectory(directory);

  for (const [name, type] of children) {
    if (
      name === ".git" ||
      name === "node_modules" ||
      name === ".vscode" ||
      name === "out"
    ) {
      continue;
    }

    const relativePath = relative
      ? `${relative}/${name}`
      : name;

    if (!safeRelativePath(relativePath)) {
      continue;
    }

    const uri = vscode.Uri.joinPath(directory, name);

    if (type === vscode.FileType.Directory) {
      result.push(...await readProjectFiles(root, relativePath));
    } else if (type === vscode.FileType.File) {
      const data = await vscode.workspace.fs.readFile(uri);

      result.push({
        path: relativePath,
        data: Buffer.from(data)
      });
    }
  }

  return result;
}

/*
 * BACUSBP1 binary format:
 *
 * 8 bytes: magic "BACUSBP1"
 * 4 bytes: JSON manifest length (unsigned big-endian)
 * N bytes: JSON manifest
 * Remaining: concatenated file contents in manifest order
 */
function buildBinaryPackage(
  files: { path: string; data: Buffer }[]
): Buffer {
  const entries: PackageEntry[] = files.map(file => ({
    path: file.path,
    size: file.data.length
  }));

  const manifest = Buffer.from(
    JSON.stringify({
      format: "BACUSBP1",
      version: 1,
      entries
    }),
    "utf8"
  );

  const header = Buffer.alloc(4);
  header.writeUInt32BE(manifest.length, 0);

  return joinBytes([
    MAGIC,
    header,
    manifest,
    ...files.map(file => file.data)
  ]);
}

function parseBinaryPackage(data: Buffer): {
  entries: PackageEntry[];
  payloadOffset: number;
} {
  if (
    data.length < 12 ||
    !data.subarray(0, 8).equals(MAGIC)
  ) {
    throw new Error("No es un paquete BACUSBP1 reconocido.");
  }

  const manifestLength = data.readUInt32BE(8);
  const manifestStart = 12;
  const payloadOffset = manifestStart + manifestLength;

  if (
    manifestLength === 0 ||
    payloadOffset > data.length
  ) {
    throw new Error("El manifiesto binario está incompleto.");
  }

  let parsed: unknown;

  try {
    parsed = JSON.parse(
      data.subarray(manifestStart, payloadOffset).toString("utf8")
    );
  } catch {
    throw new Error("El manifiesto del paquete no es JSON válido.");
  }

  if (
    !parsed ||
    typeof parsed !== "object" ||
    !("format" in parsed) ||
    !("entries" in parsed) ||
    (parsed as { format: unknown }).format !== "BACUSBP1" ||
    !Array.isArray((parsed as { entries: unknown }).entries)
  ) {
    throw new Error("La estructura del paquete no es válida.");
  }

  const entries = (parsed as { entries: unknown[] }).entries;
  let totalSize = 0;

  for (const item of entries) {
    if (
      !item ||
      typeof item !== "object" ||
      !("path" in item) ||
      !("size" in item)
    ) {
      throw new Error("Hay una entrada inválida en el paquete.");
    }

    const entry = item as PackageEntry;

    if (
      typeof entry.path !== "string" ||
      !safeRelativePath(entry.path) ||
      !Number.isSafeInteger(entry.size) ||
      entry.size < 0
    ) {
      throw new Error("Hay una ruta o tamaño inválido en el paquete.");
    }

    totalSize += entry.size;

    if (!Number.isSafeInteger(totalSize)) {
      throw new Error("El tamaño total del paquete no es válido.");
    }
  }

  if (payloadOffset + totalSize !== data.length) {
    throw new Error("El contenido del paquete está incompleto o tiene datos adicionales.");
  }

  return {
    entries: entries as PackageEntry[],
    payloadOffset
  };
}

async function chooseFolder(): Promise<vscode.Uri | undefined> {
  const folders = await vscode.window.showOpenDialog({
    canSelectFiles: false,
    canSelectFolders: true,
    canSelectMany: false,
    openLabel: "Seleccionar carpeta"
  });

  return folders?.[0];
}

async function chooseBpFile(): Promise<vscode.Uri | undefined> {
  const files = await vscode.window.showOpenDialog({
    canSelectFiles: true,
    canSelectFolders: false,
    canSelectMany: false,
    openLabel: "Seleccionar paquete .bp",
    filters: {
      "Bacus packages": ["bp"]
    }
  });

  return files?.[0];
}

async function createPackageProject(): Promise<void> {
  const name = await vscode.window.showInputBox({
    title: "Bacus Studio — Paso 1 de 3",
    prompt: "Nombre del proyecto / Project name",
    placeHolder: "Perritos",
    validateInput: value => {
      if (!value.trim()) {
        return "Escribí un nombre.";
      }

      return /^[a-zA-Z0-9._+-]+$/.test(value)
        ? null
        : "Usá letras, números, puntos, guiones o guiones bajos.";
    }
  });

  if (!name) return;

  const languages = [
    { label: "Python", description: ".py", value: "python" },
    { label: "C", description: ".c, .h", value: "c" },
    { label: "C++", description: ".cpp, .hpp", value: "cpp" },
    { label: "JavaScript", description: ".js", value: "javascript" },
    { label: "TypeScript", description: ".ts", value: "typescript" },
    { label: "HTML + CSS + JavaScript", description: "Web", value: "web" },
    { label: "Shell", description: ".sh", value: "shell" },
    { label: "Otro / Other", description: "Archivos personalizados", value: "other" }
  ];

  const language = await vscode.window.showQuickPick(languages, {
    title: "Bacus Studio — Paso 2 de 3",
    placeHolder: "Elegí el lenguaje / Choose a language"
  });

  if (!language) return;

  const defaults: Record<string, string> = {
    python: "src/main.py,README.md,assets/",
    c: "src/main.c,README.md,assets/",
    cpp: "src/main.cpp,README.md,assets/",
    javascript: "src/main.js,README.md,assets/",
    typescript: "src/main.ts,README.md,assets/",
    web: "index.html,style.css,script.js,README.md,assets/",
    shell: "src/main.sh,README.md,assets/",
    other: "README.md,assets/"
  };

  const filesInput = await vscode.window.showInputBox({
    title: "Bacus Studio — Paso 3 de 3",
    prompt: "Archivos y carpetas separados por comas",
    value: defaults[language.value],
    placeHolder: "src/main.py,assets/,README.md"
  });

  if (filesInput === undefined) return;

  const selected = filesInput
    .split(",")
    .map(item => item.trim())
    .filter(Boolean);

  if (!selected.length) {
    vscode.window.showErrorMessage("Agregá al menos un archivo o carpeta.");
    return;
  }

  const unique = new Set<string>();

  for (const item of selected) {
    const folder = item.endsWith("/");
    const cleanPath = folder ? item.slice(0, -1) : item;

    if (!safeRelativePath(cleanPath)) {
      vscode.window.showErrorMessage(`Ruta no válida: ${item}`);
      return;
    }

    if (unique.has(cleanPath)) {
      vscode.window.showErrorMessage(`Ruta repetida: ${item}`);
      return;
    }

    unique.add(cleanPath);
  }

  const parent = await chooseFolder();
  if (!parent) return;

  const root = vscode.Uri.joinPath(parent, name);

  try {
    await vscode.workspace.fs.createDirectory(root);

    const manifest = [
      `package_name=${name}`,
      "version=1.0.0",
      `description=${name} application`,
      "target_os=unknown",
      "target_arch=unknown",
      "payload_format=BACUSBP1",
      "entrypoint=",
      `language=${language.value}`,
      "package_kind=standard",
      ""
    ].join("\n");

    await vscode.workspace.fs.writeFile(
      vscode.Uri.joinPath(root, "PACKAGE.bpmanifest"),
      Buffer.from(manifest, "utf8")
    );

    for (const item of selected) {
      const isFolder = item.endsWith("/");
      const relative = isFolder ? item.slice(0, -1) : item;
      const parts = relative.split("/");
      const fileName = parts.pop()!;

      let current = root;

      for (const part of parts) {
        current = vscode.Uri.joinPath(current, part);
        await vscode.workspace.fs.createDirectory(current);
      }

      if (isFolder) {
        await vscode.workspace.fs.createDirectory(
          vscode.Uri.joinPath(current, fileName)
        );
        continue;
      }

      let content = "";

      if (relative === "README.md") {
        content = `# ${name}\n\nCreated with Bacus Studio.\n`;
      } else if (relative.endsWith(".py")) {
        content = [
          "def main():",
          '    print("¡Hola desde Bacus!")',
          "",
          'if __name__ == "__main__":',
          "    main()",
          ""
        ].join("\n");
      } else if (relative.endsWith(".c")) {
        content = [
          "#include <stdio.h>",
          "",
          "int main(void) {",
          '    puts("Hola desde Bacus");',
          "    return 0;",
          "}",
          ""
        ].join("\n");
      } else if (relative.endsWith(".cpp")) {
        content = [
          "#include <iostream>",
          "",
          "int main() {",
          '    std::cout << "Hola desde Bacus\\n";',
          "    return 0;",
          "}",
          ""
        ].join("\n");
      } else if (relative.endsWith(".js") || relative.endsWith(".ts")) {
        content = 'console.log("Hola desde Bacus");\n';
      } else if (relative.endsWith(".html")) {
        content = [
          "<!doctype html>",
          '<html lang="es">',
          "<head>",
          '  <meta charset="utf-8">',
          '  <meta name="viewport" content="width=device-width, initial-scale=1">',
          `  <title>${name}</title>`,
          '  <link rel="stylesheet" href="style.css">',
          "</head>",
          "<body>",
          `  <h1>${name}</h1>`,
          '  <script src="script.js"></script>',
          "</body>",
          "</html>",
          ""
        ].join("\n");
      } else if (relative.endsWith(".css")) {
        content = "body {\n  font-family: sans-serif;\n}\n";
      } else if (relative.endsWith(".sh")) {
        content = '#!/bin/sh\nprintf "%s\\n" "Hola desde Bacus"\n';
      }

      await vscode.workspace.fs.writeFile(
        vscode.Uri.joinPath(current, fileName),
        Buffer.from(content, "utf8")
      );
    }

    const projectFiles = await readProjectFiles(root);

    const bp = buildBinaryPackage(projectFiles);

    await vscode.workspace.fs.writeFile(
      vscode.Uri.joinPath(parent, `${name}.bp`),
      bp
    );

    const readmeUri = vscode.Uri.joinPath(root, "README.md");

    if (selected.includes("README.md")) {
      const doc = await vscode.workspace.openTextDocument(readmeUri);
      await vscode.window.showTextDocument(doc);
    }

    await vscode.commands.executeCommand("workbench.view.explorer");

    vscode.window.showInformationMessage(
      `Bacus Studio: proyecto "${name}" y paquete "${name}.bp" creados.`
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);

    vscode.window.showErrorMessage(
      `No se pudo crear el proyecto o el paquete: ${message}`
    );
  }
}

async function validateProject(): Promise<void> {
  const root = await chooseFolder();
  if (!root) return;

  try {
    const uri = vscode.Uri.joinPath(root, "PACKAGE.bpmanifest");
    const bytes = await vscode.workspace.fs.readFile(uri);
    const text = Buffer.from(bytes).toString("utf8");

    const required = [
      "package_name",
      "version",
      "description",
      "payload_format",
      "language"
    ];

    const missing = required.filter(key => {
      const value = manifestValue(text, key);
      return value === undefined || value.length === 0;
    });

    if (missing.length) {
      vscode.window.showErrorMessage(
        `Manifiesto incompleto. Faltan: ${missing.join(", ")}`
      );
      return;
    }

    vscode.window.showInformationMessage(
      "Manifiesto válido. Esto no garantiza que la aplicación pueda ejecutarse."
    );
  } catch {
    vscode.window.showErrorMessage(
      "No se encontró PACKAGE.bpmanifest o no se pudo leer."
    );
  }
}

async function inspectPackage(): Promise<void> {
  const uri = await chooseBpFile();
  if (!uri) return;

  try {
    const bytes = Buffer.from(
      await vscode.workspace.fs.readFile(uri)
    );

    const parsed = parseBinaryPackage(bytes);

    const lines = [
      `Archivo: ${path.basename(uri.fsPath)}`,
      "Formato: BACUSBP1",
      `Tamaño: ${bytes.length} bytes`,
      `Cantidad de archivos: ${parsed.entries.length}`,
      "",
      "Contenido:"
    ];

    for (const entry of parsed.entries) {
      lines.push(`- ${entry.path} (${entry.size} bytes)`);
    }

    const doc = await vscode.workspace.openTextDocument({
      language: "plaintext",
      content: lines.join("\n")
    });

    await vscode.window.showTextDocument(doc);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);

    vscode.window.showErrorMessage(
      `No se pudo inspeccionar el paquete: ${message}`
    );
  }
}

export function activate(context: vscode.ExtensionContext): void {
  context.subscriptions.push(
    vscode.commands.registerCommand(
      "bacus.createPackage",
      createPackageProject
    ),
    vscode.commands.registerCommand(
      "bacus.validatePackage",
      validateProject
    ),
    vscode.commands.registerCommand(
      "bacus.inspectPackage",
      inspectPackage
    )
  );
}

export function deactivate(): void {}
