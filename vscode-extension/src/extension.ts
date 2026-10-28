
import * as vscode from "vscode";

export function activate(context: vscode.ExtensionContext) {
  const createPackage = vscode.commands.registerCommand(
    "bacus.createPackage",
    async () => {
      const name = await vscode.window.showInputBox({
        title: "Bacus Studio / Paso 1 de 4",
        prompt: "Nombre de la aplicación / Application name",
        placeHolder: "Perritos",
        validateInput: value =>
          /^[a-zA-Z0-9._+-]+$/.test(value)
            ? null
            : "Usá letras, números, puntos, guiones o guiones bajos."
      });
      if (!name) return;

      const language = await vscode.window.showQuickPick(
        [
          { label: "Python", description: ".py", value: "python" },
          { label: "C", description: ".c, .h", value: "c" },
          { label: "C++", description: ".cpp, .hpp", value: "cpp" },
          { label: "JavaScript", description: ".js", value: "javascript" },
          { label: "TypeScript", description: ".ts", value: "typescript" },
          { label: "HTML + CSS + JavaScript", description: "Web", value: "web" },
          { label: "Shell", description: ".sh", value: "shell" },
          { label: "Otro / Other", description: "Archivos personalizados", value: "other" }
        ],
        { title: "Bacus Studio / Paso 2 de 4", placeHolder: "Elegí el lenguaje / Choose a language" }
      );
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

      const files = await vscode.window.showInputBox({
        title: "Bacus Studio / Paso 3 de 4",
        prompt: "Archivos y carpetas separados por comas",
        value: defaults[language.value],
        placeHolder: "src/main.py,assets/,README.md"
      });
      if (files === undefined) return;

      const selected = files.split(",").map(x => x.trim()).filter(Boolean);
      if (!selected.length) {
        vscode.window.showErrorMessage("Agregá al menos un archivo o carpeta.");
        return;
      }

      for (const path of selected) {
        if (
          path.startsWith("/") ||
          path.includes("\\") ||
          path.split("/").some(part => part === ".." || part === ".") ||
          path.includes("\0")
        ) {
          vscode.window.showErrorMessage("Ruta no válida: " + path);
          return;
        }
      }

      const parent = await vscode.window.showOpenDialog({
        canSelectFiles: false,
        canSelectFolders: true,
        canSelectMany: false,
        openLabel: "Crear proyecto aquí / Create project here"
      });
      if (!parent?.[0]) return;

      const root = vscode.Uri.joinPath(parent[0], name);
      try {
        await vscode.workspace.fs.createDirectory(root);
      } catch {
        vscode.window.showErrorMessage(
          "No se pudo crear la carpeta. ¿Ya existe?"
        );
        return;
      }

      const manifest = [
        `package_name=${name}`,
        "version=1.0.0",
        `description=${name} application`,
        "target_os=unknown",
        "target_arch=unknown",
        "payload_format=raw-v1",
        "entrypoint=",
        `language=${language.value}`,
        `file_count=${selected.filter(p => !p.endsWith("/")).length}`,
        "package_kind=standard",
        ""
      ].join("\n");

      await vscode.workspace.fs.writeFile(
        vscode.Uri.joinPath(root, "PACKAGE.bpmanifest"),
        new TextEncoder().encode(manifest)
      );

      for (const path of selected) {
        const isFolder = path.endsWith("/");
        const uri = vscode.Uri.joinPath(root, path);
        if (isFolder) {
          await vscode.workspace.fs.createDirectory(uri);
          continue;
        }

        await vscode.workspace.fs.createDirectory(
          vscode.Uri.joinPath(uri, "..")
        );

        let content = "";
        if (path === "README.md") {
          content = `# ${name}\n\nCreated with Bacus Studio.\n`;
        } else if (path.endsWith(".py")) {
          content = 'def main():\n    print("¡Hola desde Bacus!")\n\nif __name__ == "__main__":\n    main()\n';
        } else if (path.endsWith(".c")) {
          content = '#include <stdio.h>\n\nint main(void) {\n    puts("Hola desde Bacus");\n    return 0;\n}\n';
        } else if (path.endsWith(".cpp")) {
          content = '#include <iostream>\n\nint main() {\n    std::cout << "Hola desde Bacus\\n";\n    return 0;\n}\n';
        } else if (path.endsWith(".js")) {
          content = 'console.log("Hola desde Bacus");\n';
        } else if (path.endsWith(".ts")) {
          content = 'console.log("Hola desde Bacus");\n';
        } else if (path.endsWith(".html")) {
          content = '<!doctype html>\n<html lang="es">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1">\n<title>' + name + '</title>\n<link rel="stylesheet" href="style.css">\n</head>\n<body>\n<h1>' + name + '</h1>\n<script src="script.js"></script>\n</body>\n</html>\n';
        } else if (path.endsWith(".sh")) {
          content = '#!/bin/sh\nprintf "%s\\n" "Hola desde Bacus"\n';
        }

        await vscode.workspace.fs.writeFile(
          uri,
          new TextEncoder().encode(content)
        );
      }

      const readme = vscode.Uri.joinPath(root, "README.md");
      const openUri = selected.includes("README.md")
        ? readme
        : vscode.Uri.joinPath(root, selected.find(p => !p.endsWith("/")) || "PACKAGE.bpmanifest");

      const doc = await vscode.workspace.openTextDocument(openUri);
      await vscode.window.showTextDocument(doc);
      await vscode.commands.executeCommand(
        "workbench.view.explorer"
      );

      vscode.window.showInformationMessage(
        `Bacus Studio: proyecto "${name}" creado. Para generar el .bp hace falta ejecutar el empaquetador.`
      );
    }
  );

  context.subscriptions.push(createPackage);
}

export function deactivate() {}
