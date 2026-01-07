# Hugo to Obsidian 逆向转换脚本
# 用途: 将现有 Hugo 文章转换到 Obsidian 笔记结构

param(
    [string]$HugoContentPath = "D:\Study\Blog\DeerBlog\content\post",
    [string]$ObsidianPath = "D:\a_OneDrive\OneDrive\DeerObsidian",
    [switch]$DryRun
)

function Write-Info { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }

# 目录映射规则
$categoryMapping = @{
    # FPGA 相关
    'a01_xilinx-jtag驱动' = @{ Dir = '专业知识\FPGA'; Category = 'FPGA' }
    'a02_fpga学习资源' = @{ Dir = '专业知识\FPGA'; Category = 'FPGA' }
    
    # 工具类
    'b01_通用工具' = @{ Dir = '工具箱\通用工具'; Category = '工具' }
    'b02_FPGA开发工具' = @{ Dir = '工具箱\FPGA工具'; Category = '工具' }
    'b03_编程工具' = @{ Dir = '工具箱\编程工具'; Category = '工具' }
    'b04_学习工具' = @{ Dir = '工具箱\学习工具'; Category = '工具' }
    'b05_系统工具' = @{ Dir = '工具箱\系统工具'; Category = '工具' }
    
    # 虚拟化系统
    'b11_PVE安装' = @{ Dir = '专业知识\虚拟化'; Category = '系统' }
    'b12_PVE安装飞牛' = @{ Dir = '专业知识\虚拟化'; Category = '系统' }
    'b13_PVE安装WIN10' = @{ Dir = '专业知识\虚拟化'; Category = '系统' }
    
    # 随笔
    'd01_听说' = @{ Dir = '随笔\2025年'; Category = '随笔' }
}

Write-Info "开始扫描 Hugo 文章..."   

$articles = Get-ChildItem -Path $HugoContentPath -Recurse -Filter "index.md"
Write-Info "找到 $($articles.Count) 篇文章"

$successCount = 0

foreach ($article in $articles) {
    $folderName = $article.Directory.Name
    $yearFolder = $article.Directory.Parent.Name
    
    Write-Info "处理: $folderName"
    
    # 获取目标目录
    if ($categoryMapping.ContainsKey($folderName)) {
        $mapping = $categoryMapping[$folderName]
        $targetDir = Join-Path $ObsidianPath $mapping.Dir
        $category = $mapping.Category
    } else {
        Write-Warn "  未定义映射关系,跳过"
        continue
    }
    
    # 读取文章内容
    $content = Get-Content $article.FullName -Raw -Encoding UTF8
    
    # 提取 front matter
    if ($content -match '(?s)^---\s*\n(.*?)\n---\s*\n(.*)$') {
        $frontMatter = $matches[1]
        $body = $matches[2]
        
        # 解析 front matter 字段
        $fm = @{}
        $frontMatter -split "`n" | ForEach-Object {
            if ($_ -match '^(\w+):\s*(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim() -replace '^["'']|["'']$', ''
                $fm[$key] = $value
            }
        }
        
        # 构建新的 front matter
        $newFM = "---`n"
        $newFM += "publish: true`n"
        $newFM += "title: `"$($fm['title'])`"`n"
        $newFM += "slug: `"$($fm['slug'])`"`n"
        $newFM += "date: $($fm['date'])`n"
        if ($fm['description']) {
            $newFM += "description: `"$($fm['description'])`"`n"
        }
        if ($fm['tags']) {
            $newFM += "tags: $($fm['tags'])`n"
        }
        if ($fm['categories']) {
            $newFM += "categories: $($fm['categories'])`n"
        }
        if ($fm['image']) {
            $newFM += "image: `"img/$($fm['image'])`"`n"
        }
        $newFM += "published_path: $yearFolder/$folderName`n"
        $newFM += "---`n"
        
        # 处理正文中的图片路径
        $newBody = $body -replace '!\[([^\]]*)\]\(([^/)]+)\)', '![$1](img/$2)'
        
        # 组合新内容
        $newContent = $newFM + $newBody
        
        if (-not $DryRun) {
            # 创建目标目录
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                Write-Info "  创建目录: $targetDir"
            }
            
            # 确保 img 目录存在
            $imgTargetDir = Join-Path (Join-Path $ObsidianPath ($mapping.Dir -split '\\')[0]) "img"
            if (-not (Test-Path $imgTargetDir)) {
                New-Item -ItemType Directory -Path $imgTargetDir -Force | Out-Null
                Write-Info "  创建图片目录: $imgTargetDir"
            }
            
            # 生成文件名
            $fileName = "$($fm['title'] -replace '[\\/:*?"<>|]', '_').md"
            $targetFile = Join-Path $targetDir $fileName
            
            # 写入文件
            Set-Content -Path $targetFile -Value $newContent -Encoding UTF8 -NoNewline
            Write-Success "  已转换: $targetFile"
            
            # 复制图片
            $imageFiles = Get-ChildItem -Path $article.Directory.FullName -File | Where-Object { $_.Extension -match '\.(jpg|jpeg|png|gif|webp)$' }
            if ($imageFiles) {
                foreach ($img in $imageFiles) {
                    $imgTarget = Join-Path $imgTargetDir $img.Name
                    Copy-Item $img.FullName -Destination $imgTarget -Force
                    Write-Info "  复制图片: $($img.Name) -> $imgTargetDir"
                }
            }
            
            $successCount++
        } else {
            Write-Info "  [DRY RUN] 将转换到: $targetDir\$($fm['title']).md"
        }
    } else {
        Write-Warn "  无法解析 front matter"
    }
}

Write-Host "`n========== 转换完成 ==========" -ForegroundColor Magenta
Write-Success "成功转换: $successCount 篇"
Write-Host "==============================`n" -ForegroundColor Magenta
