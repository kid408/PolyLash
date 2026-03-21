import fs from "node:fs";
import path from "node:path";

const TEXT_FILE_EXTENSIONS = new Set([
  ".txt",
  ".md",
  ".markdown",
  ".json",
  ".yaml",
  ".yml",
  ".csv",
  ".tsv",
  ".log",
  ".ini",
  ".cfg",
  ".conf",
  ".js",
  ".ts",
  ".mjs",
  ".cjs",
  ".py",
  ".go",
  ".gd",
  ".html",
  ".css",
  ".xml",
]);

function ensureInsideRoot(rootPath, candidatePath) {
  const normalizedRoot = path.resolve(rootPath);
  const normalizedCandidate = path.resolve(candidatePath);

  if (
    normalizedCandidate !== normalizedRoot &&
    !normalizedCandidate.startsWith(`${normalizedRoot}${path.sep}`)
  ) {
    throw new Error(`路径超出白名单目录: ${normalizedCandidate}`);
  }

  return normalizedCandidate;
}

function looksLikeTextFile(filePath) {
  const extension = path.extname(filePath).toLowerCase();
  return TEXT_FILE_EXTENSIONS.has(extension);
}

function buildRootsMap(workspaceRoots) {
  const map = new Map();
  for (const root of workspaceRoots) {
    map.set(root.alias, root.absolutePath);
  }
  return map;
}

function getRootPath(rootsMap, rootAlias) {
  const rootPath = rootsMap.get(rootAlias);
  if (!rootPath) {
    throw new Error(`未知的 root_alias: ${rootAlias}`);
  }
  return rootPath;
}

function resolveWithinRoot(rootsMap, rootAlias, relativePath = ".") {
  if (path.isAbsolute(relativePath)) {
    throw new Error("只允许传相对白名单目录的路径");
  }
  const rootPath = getRootPath(rootsMap, rootAlias);
  return ensureInsideRoot(rootPath, path.resolve(rootPath, relativePath));
}

function toRelative(rootPath, absolutePath) {
  const relative = path.relative(rootPath, absolutePath);
  return relative || ".";
}

function listDirectoryInternal(rootPath, absoluteDirectoryPath, maxItems) {
  const entries = fs
    .readdirSync(absoluteDirectoryPath, { withFileTypes: true })
    .map((entry) => {
      const absolutePath = path.join(absoluteDirectoryPath, entry.name);
      const stat = fs.statSync(absolutePath);
      return {
        name: entry.name,
        type: entry.isDirectory() ? "directory" : "file",
        relativePath: toRelative(rootPath, absolutePath),
        size: stat.size,
        modifiedAt: stat.mtime.toISOString(),
      };
    })
    .sort((left, right) => {
      if (left.type !== right.type) {
        return left.type === "directory" ? -1 : 1;
      }
      return left.name.localeCompare(right.name, "zh-CN");
    });

  return entries.slice(0, maxItems);
}

function walkFiles(rootPath, startPath, visitor) {
  const stack = [startPath];
  while (stack.length > 0) {
    const current = stack.pop();
    const entries = fs.readdirSync(current, { withFileTypes: true });
    for (const entry of entries) {
      const absolutePath = path.join(current, entry.name);
      ensureInsideRoot(rootPath, absolutePath);
      if (entry.isDirectory()) {
        stack.push(absolutePath);
        continue;
      }
      visitor(absolutePath);
    }
  }
}

export class FileTools {
  constructor(config) {
    this.config = config;
    this.rootsMap = buildRootsMap(config.workspaceRoots);
  }

  listRoots() {
    return this.config.workspaceRoots.map((root) => ({
      alias: root.alias,
      absolutePath: root.absolutePath,
    }));
  }

  listFiles({ root_alias, relative_path = "." }) {
    const rootPath = getRootPath(this.rootsMap, root_alias);
    const absoluteDirectoryPath = resolveWithinRoot(
      this.rootsMap,
      root_alias,
      relative_path,
    );
    if (!fs.existsSync(absoluteDirectoryPath)) {
      throw new Error(`目录不存在: ${relative_path}`);
    }
    if (!fs.statSync(absoluteDirectoryPath).isDirectory()) {
      throw new Error(`目标不是目录: ${relative_path}`);
    }

    return {
      rootAlias: root_alias,
      directory: toRelative(rootPath, absoluteDirectoryPath),
      entries: listDirectoryInternal(
        rootPath,
        absoluteDirectoryPath,
        this.config.maxDirectoryItems,
      ),
    };
  }

  readTextFile({ root_alias, relative_path }) {
    const rootPath = getRootPath(this.rootsMap, root_alias);
    const absoluteFilePath = resolveWithinRoot(
      this.rootsMap,
      root_alias,
      relative_path,
    );
    if (!fs.existsSync(absoluteFilePath)) {
      throw new Error(`文件不存在: ${relative_path}`);
    }
    if (!fs.statSync(absoluteFilePath).isFile()) {
      throw new Error(`目标不是文件: ${relative_path}`);
    }
    if (!looksLikeTextFile(absoluteFilePath)) {
      throw new Error("当前版本只允许读取常见文本文件");
    }

    const content = fs.readFileSync(absoluteFilePath, "utf8");
    return {
      rootAlias: root_alias,
      relativePath: toRelative(rootPath, absoluteFilePath),
      truncated: content.length > this.config.maxReadChars,
      content: content.slice(0, this.config.maxReadChars),
    };
  }

  searchText({ root_alias, query, relative_path = "." }) {
    if (!query || !query.trim()) {
      throw new Error("query 不能为空");
    }

    const rootPath = getRootPath(this.rootsMap, root_alias);
    const absoluteStartPath = resolveWithinRoot(
      this.rootsMap,
      root_alias,
      relative_path,
    );
    if (!fs.existsSync(absoluteStartPath)) {
      throw new Error(`路径不存在: ${relative_path}`);
    }

    const results = [];
    const loweredQuery = query.toLowerCase();

    const visitFile = (absoluteFilePath) => {
      if (results.length >= this.config.maxSearchResults) {
        return;
      }
      if (!looksLikeTextFile(absoluteFilePath)) {
        return;
      }
      const content = fs.readFileSync(absoluteFilePath, "utf8");
      const lowered = content.toLowerCase();
      const index = lowered.indexOf(loweredQuery);
      if (index === -1) {
        return;
      }

      const start = Math.max(0, index - 60);
      const end = Math.min(content.length, index + query.length + 120);
      results.push({
        relativePath: toRelative(rootPath, absoluteFilePath),
        snippet: content.slice(start, end).replace(/\s+/g, " ").trim(),
      });
    };

    const stat = fs.statSync(absoluteStartPath);
    if (stat.isDirectory()) {
      walkFiles(rootPath, absoluteStartPath, visitFile);
    } else {
      visitFile(absoluteStartPath);
    }

    return {
      rootAlias: root_alias,
      query,
      results,
    };
  }

  buildPendingAction(name, args) {
    return {
      id: `pending_${Date.now()}`,
      name,
      args,
      createdAt: new Date().toISOString(),
    };
  }

  previewPendingAction(action) {
    switch (action.name) {
      case "write_text_file":
        return `准备覆盖写入 ${action.args.root_alias}:${action.args.relative_path}`;
      case "append_text_file":
        return `准备追加写入 ${action.args.root_alias}:${action.args.relative_path}`;
      case "rename_file":
        return `准备将 ${action.args.root_alias}:${action.args.relative_path} 重命名为 ${action.args.new_name}`;
      case "move_file":
        return `准备将 ${action.args.root_alias}:${action.args.source_relative_path} 移动到 ${action.args.destination_relative_path}`;
      default:
        return `准备执行 ${action.name}`;
    }
  }

  executePendingAction(action) {
    switch (action.name) {
      case "write_text_file":
        return this.writeTextFile(action.args);
      case "append_text_file":
        return this.appendTextFile(action.args);
      case "rename_file":
        return this.renameFile(action.args);
      case "move_file":
        return this.moveFile(action.args);
      default:
        throw new Error(`不支持的待确认动作: ${action.name}`);
    }
  }

  writeTextFile({ root_alias, relative_path, content }) {
    const absoluteFilePath = resolveWithinRoot(
      this.rootsMap,
      root_alias,
      relative_path,
    );
    fs.mkdirSync(path.dirname(absoluteFilePath), { recursive: true });
    fs.writeFileSync(absoluteFilePath, content, "utf8");
    return {
      ok: true,
      action: "write_text_file",
      rootAlias: root_alias,
      relativePath: relative_path,
      length: content.length,
    };
  }

  appendTextFile({ root_alias, relative_path, content }) {
    const absoluteFilePath = resolveWithinRoot(
      this.rootsMap,
      root_alias,
      relative_path,
    );
    fs.mkdirSync(path.dirname(absoluteFilePath), { recursive: true });
    fs.appendFileSync(absoluteFilePath, content, "utf8");
    return {
      ok: true,
      action: "append_text_file",
      rootAlias: root_alias,
      relativePath: relative_path,
      length: content.length,
    };
  }

  renameFile({ root_alias, relative_path, new_name }) {
    if (!new_name || new_name.includes("/") || new_name.includes("\\")) {
      throw new Error("new_name 只能是文件名，不能包含路径分隔符");
    }

    const absoluteSourcePath = resolveWithinRoot(
      this.rootsMap,
      root_alias,
      relative_path,
    );
    if (!fs.existsSync(absoluteSourcePath)) {
      throw new Error(`源文件不存在: ${relative_path}`);
    }

    const rootPath = getRootPath(this.rootsMap, root_alias);
    const absoluteTargetPath = ensureInsideRoot(
      rootPath,
      path.join(path.dirname(absoluteSourcePath), new_name),
    );

    fs.renameSync(absoluteSourcePath, absoluteTargetPath);
    return {
      ok: true,
      action: "rename_file",
      rootAlias: root_alias,
      from: relative_path,
      to: path.relative(rootPath, absoluteTargetPath),
    };
  }

  moveFile({ root_alias, source_relative_path, destination_relative_path }) {
    const absoluteSourcePath = resolveWithinRoot(
      this.rootsMap,
      root_alias,
      source_relative_path,
    );
    const absoluteTargetPath = resolveWithinRoot(
      this.rootsMap,
      root_alias,
      destination_relative_path,
    );
    if (!fs.existsSync(absoluteSourcePath)) {
      throw new Error(`源路径不存在: ${source_relative_path}`);
    }

    fs.mkdirSync(path.dirname(absoluteTargetPath), { recursive: true });
    fs.renameSync(absoluteSourcePath, absoluteTargetPath);
    return {
      ok: true,
      action: "move_file",
      rootAlias: root_alias,
      from: source_relative_path,
      to: destination_relative_path,
    };
  }
}
