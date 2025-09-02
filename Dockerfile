# =======================
# 第一阶段：代码混淆和优化
# =======================
FROM node:20-alpine AS obfuscator

WORKDIR /build

# 复制已混淆的代码和其他文件
COPY app.js ./server.js
COPY package.json ./
COPY index.html ./

# 创建伪装的目录结构和文件
RUN mkdir -p static/css static/js static/images public config logs data && \
    echo '/* Personal Navigation Styles */' > static/css/main.css && \
    echo '// Navigation Dashboard JS' > static/js/app.js && \
    echo '{"theme": "modern"}' > config/app.json

# 创建伪装的 package.json
RUN echo '{"name":"personal-navigation-dashboard","version":"1.2.3","description":"Modern personal navigation and bookmark management","main":"server.js","scripts":{"start":"node server.js"},"keywords":["navigation","dashboard","bookmarks"],"author":"WebDev Team","license":"MIT","dependencies":{"axios":"^1.6.2"}}' > package.json

# =======================
# 第二阶段：生产运行环境
# =======================
FROM node:20-alpine

WORKDIR /app

# 创建非 root 用户
RUN addgroup -g 1001 -S nodejs && \
    adduser -S webapp -u 1001 -G nodejs

# 安装运行时依赖
RUN apk add --no-cache curl bash dumb-init && \
    rm -rf /var/cache/apk/*

# 从构建阶段复制文件
COPY --from=obfuscator /build/package.json ./
COPY --from=obfuscator /build/server.js ./
COPY --from=obfuscator /build/index.html ./
COPY --from=obfuscator /build/static/ ./static/
COPY --from=obfuscator /build/public/ ./public/
COPY --from=obfuscator /build/config/ ./config/

# 安装依赖
RUN npm ci --only=production && \
    npm cache clean --force

# 创建必要目录并设置权限
RUN mkdir -p logs data && \
    chown -R webapp:nodejs /app

# 切换到非 root 用户
USER webapp

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# 暴露端口
EXPOSE 3000

# 使用 dumb-init 启动
ENTRYPOINT ["dumb-init", "--"]
CMD ["npm", "start"]
