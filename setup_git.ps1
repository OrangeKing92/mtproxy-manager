# Git配置和GitHub上传脚本
# 请在安装Git后运行此脚本

# 配置Git用户信息（请替换为您的信息）
Write-Host "配置Git用户信息..." -ForegroundColor Green
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# 初始化Git仓库
Write-Host "初始化Git仓库..." -ForegroundColor Green
git init

# 添加所有文件
Write-Host "添加项目文件..." -ForegroundColor Green
git add .

# 创建初始提交
Write-Host "创建初始提交..." -ForegroundColor Green
git commit -m "Initial commit: Python MTProxy项目"

# 设置主分支名称
git branch -M main

Write-Host "Git仓库初始化完成！" -ForegroundColor Green
Write-Host "下一步：" -ForegroundColor Yellow
Write-Host "1. 在GitHub上创建新仓库" -ForegroundColor White
Write-Host "2. 运行推送命令将代码上传" -ForegroundColor White
