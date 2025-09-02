# =======================
# 第一阶段：代码混淆和优化
# =======================
FROM node:20-alpine AS obfuscator

WORKDIR /build

# 安装混淆工具
RUN npm install -g javascript-obfuscator terser

# 复制源码
COPY app.js ./
COPY package.json ./
COPY index.html ./

# 创建伪装的目录结构和文件
RUN mkdir -p static/css static/js static/images public config logs data && \
    echo '/* Personal Navigation Styles */' > static/css/main.css && \
    echo '// Navigation Dashboard JS' > static/js/app.js && \
    echo '{"theme": "modern"}' > config/app.json

# 极致代码混淆 - 最高安全级别
RUN javascript-obfuscator app.js \
    --output app.obf.js \
    --compact true \
    --control-flow-flattening true \
    --control-flow-flattening-threshold 1.0 \
    --dead-code-injection true \
    --dead-code-injection-threshold 0.8 \
    --debug-protection true \
    --debug-protection-interval 2000 \
    --disable-console-output true \
    --domain-lock '' \
    --exclude '' \
    --force-transform-strings true \
    --identifier-names-cache-size 500 \
    --identifier-names-generator hexadecimal \
    --identifiers-prefix '_0x' \
    --identifiers-dictionary '' \
    --ignore-imports false \
    --input-file-name '' \
    --log false \
    --numbers-to-expressions true \
    --options-preset high-obfuscation \
    --rename-globals true \
    --rename-properties true \
    --rename-properties-mode unsafe \
    --reserved-names '' \
    --reserved-strings '' \
    --rotate-string-array true \
    --seed 0 \
    --self-defending true \
    --shuffle-string-array true \
    --simplify true \
    --source-map false \
    --source-map-base-url '' \
    --source-map-file-name '' \
    --source-map-mode separate \
    --split-strings true \
    --split-strings-chunk-length 5 \
    --string-array true \
    --string-array-calls-transform true \
    --string-array-calls-transform-threshold 1.0 \
    --string-array-encoding 'rc4' \
    --string-array-index-shift true \
    --string-array-rotate true \
    --string-array-shuffle true \
    --string-array-wrappers-count 5 \
    --string-array-wrappers-chained-calls true \
    --string-array-wrappers-parameters-max-count 5 \
    --string-array-wrappers-type 'function' \
    --string-array-threshold 1.0 \
    --target 'node' \
    --transform-object-keys true \
    --unicode-escape-sequence true

# 极致压缩代码
RUN terser app.obf.js \
    --compress drop_console=true,drop_debugger=true,pure_funcs=['console.log','console.info','console.debug','console.warn'],unsafe=true,unsafe_comps=true,unsafe_Function=true,unsafe_math=true,unsafe_symbols=true,unsafe_methods=true,unsafe_proto=true,unsafe_regexp=true,unsafe_undefined=true,switches=true,dead_code=true,drop_vars=true,keep_infinity=false,reduce_funcs=true,reduce_vars=true,toplevel=true \
    --mangle toplevel=true,eval=true,keep_fnames=false,reserved=['require','module','exports'] \
    --output server.js && \
    rm app.js app.obf.js

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
