const jsonBody = (schema) => ({
  required: true,
  content: {'application/json': {schema}},
});

const objectSchema = (properties, required = Object.keys(properties)) => ({
  type: 'object',
  properties,
  required,
});

const field = (type, options = {}) => ({type, ...options});
const uuid = field('string', {format: 'uuid'});
const string = field('string');

const operation = (summary, {
  tag,
  success = 200,
  security = true,
  parameters = [],
  requestBody,
  description,
} = {}) => ({
  tags: [tag],
  summary,
  ...(description ? {description} : {}),
  ...(security ? {} : {security: []}),
  ...(parameters.length ? {parameters} : {}),
  ...(requestBody ? {requestBody} : {}),
  responses: {
    [success]: {description: 'Thành công'},
    400: {description: 'Dữ liệu không hợp lệ'},
    401: {description: 'Chưa xác thực hoặc phiên không hợp lệ'},
    403: {description: 'Không đủ quyền'},
    404: {description: 'Không tìm thấy tài nguyên'},
  },
});

const idParameter = {
  name: 'id',
  in: 'path',
  required: true,
  schema: uuid,
  description: 'UUID của tài nguyên',
};

const childId = [idParameter];

export const openApiSpec = {
  openapi: '3.0.3',
  info: {
    title: 'ChildGuard API',
    version: '1.0.0',
    description: 'REST API cho ứng dụng ChildGuard. Các endpoint riêng tư dùng JWT Bearer token.',
  },
  servers: [{url: '/', description: 'Cùng máy chủ với Swagger UI'}],
  security: [{BearerAuth: []}],
  tags: [
    {name: 'Health'},
    {name: 'Authentication'},
    {name: 'Profile'},
    {name: 'Children'},
    {name: 'Devices'},
    {name: 'Agreements'},
    {name: 'Check-ins'},
    {name: 'Location'},
    {name: 'Administration'},
  ],
  components: {
    securitySchemes: {
      BearerAuth: {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
        description: 'Nhập JWT nhận được sau khi xác minh OTP.',
      },
    },
    schemas: {
      Error: objectSchema({message: string}),
      Challenge: objectSchema({
        challengeId: uuid,
        message: string,
        kind: field('string', {enum: ['login', 'verify']}),
      }, ['challengeId', 'message']),
      Session: objectSchema({
        token: string,
        user: objectSchema({
          id: uuid,
          email: field('string', {format: 'email'}),
          username: string,
          name: string,
          role: field('string', {enum: ['parent', 'child', 'staff', 'admin']}),
          verified: field('boolean'),
        }),
      }),
      ChildInput: objectSchema({
        name: field('string', {minLength: 1, maxLength: 80}),
        age: field('integer', {minimum: 1, maximum: 17}),
        daily_limit: field('integer', {minimum: 15, maximum: 1440}),
      }),
      LocationInput: objectSchema({
        latitude: field('number', {minimum: -90, maximum: 90}),
        longitude: field('number', {minimum: -180, maximum: 180}),
        accuracy: field('number', {minimum: 0, maximum: 100000}),
      }),
    },
  },
  paths: {
    '/health': {
      get: operation('Kiểm tra trạng thái API và cơ sở dữ liệu', {tag: 'Health', security: false}),
    },
    '/auth/register': {
      post: operation('Tạo tài khoản và gửi OTP xác minh email', {
        tag: 'Authentication', security: false, success: 201,
        requestBody: jsonBody(objectSchema({
          email: field('string', {format: 'email', maxLength: 254}),
          username: field('string', {pattern: '^[a-zA-Z0-9_]{3,32}$'}),
          name: field('string', {minLength: 2, maxLength: 80}),
          password: field('string', {minLength: 10, maxLength: 72}),
        })),
      }),
    },
    '/auth/login': {
      post: operation('Đăng nhập bằng username/email và mật khẩu; yêu cầu OTP', {
        tag: 'Authentication', security: false,
        requestBody: jsonBody(objectSchema({username: string, password: string})),
      }),
    },
    '/auth/otp': {
      post: operation('Xác minh OTP để hoàn tất đăng nhập hoặc xác minh email', {
        tag: 'Authentication', security: false,
        requestBody: jsonBody(objectSchema({
          challengeId: uuid,
          code: field('string', {pattern: '^\\d{6}$'}),
        })),
      }),
    },
    '/auth/google/start': {
      get: operation('Bắt đầu đăng nhập Google; chuyển hướng đến Google OAuth', {
        tag: 'Authentication', security: false,
        parameters: [{
          name: 'verifierHash', in: 'query', required: true,
          schema: field('string', {pattern: '^[a-f0-9]{64}$'}),
        }],
      }),
    },
    '/auth/google/callback': {
      get: operation('Callback OAuth của Google; chuyển hướng về ứng dụng', {
        tag: 'Authentication', security: false,
        parameters: [
          {name: 'code', in: 'query', required: true, schema: string},
          {name: 'state', in: 'query', required: true, schema: string},
        ],
      }),
    },
    '/auth/google/exchange': {
      post: operation('Đổi mã OAuth lấy phiên hoặc yêu cầu xác minh OTP', {
        tag: 'Authentication', security: false,
        requestBody: jsonBody(objectSchema({
          code: field('string', {minLength: 20, maxLength: 100}),
          verifier: field('string', {minLength: 32, maxLength: 100}),
        })),
      }),
    },
    '/me': {
      get: operation('Lấy thông tin tài khoản hiện tại', {tag: 'Profile'}),
      patch: operation('Cập nhật tên tài khoản', {
        tag: 'Profile',
        requestBody: jsonBody(objectSchema({name: field('string', {minLength: 2, maxLength: 80})})),
      }),
    },
    '/me/email': {
      post: operation('Yêu cầu đổi email; OTP được gửi đến email mới', {
        tag: 'Profile',
        requestBody: jsonBody(objectSchema({email: field('string', {format: 'email', maxLength: 254})})),
      }),
    },
    '/children': {
      get: operation('Liệt kê hồ sơ trẻ được liên kết với tài khoản', {tag: 'Children'}),
      post: operation('Tạo hồ sơ trẻ (chỉ phụ huynh)', {
        tag: 'Children', success: 201,
        requestBody: jsonBody({'$ref': '#/components/schemas/ChildInput'}),
      }),
    },
    '/children/{id}': {
      put: operation('Cập nhật hồ sơ trẻ (chỉ phụ huynh sở hữu)', {
        tag: 'Children', parameters: childId,
        requestBody: jsonBody({'$ref': '#/components/schemas/ChildInput'}),
      }),
      delete: operation('Xóa hồ sơ trẻ (chỉ phụ huynh sở hữu)', {
        tag: 'Children', success: 204, parameters: childId,
      }),
    },
    '/children/{id}/time-budget': {
      get: operation('Lấy hạn mức thời gian hiện tại và số phút thưởng', {tag: 'Children', parameters: childId}),
    },
    '/children/{id}/link': {
      post: operation('Liên kết tài khoản trẻ đã xác minh (chỉ phụ huynh)', {
        tag: 'Children', parameters: childId,
        requestBody: jsonBody(objectSchema({email: field('string', {format: 'email'})})),
      }),
    },
    '/children/{id}/devices': {
      get: operation('Liệt kê thiết bị của hồ sơ trẻ', {tag: 'Devices', parameters: childId}),
      post: operation('Thêm thiết bị cho hồ sơ trẻ (chỉ phụ huynh)', {
        tag: 'Devices', success: 201, parameters: childId,
        requestBody: jsonBody(objectSchema({name: field('string', {minLength: 1, maxLength: 80})})),
      }),
    },
    '/devices/{id}': {
      put: operation('Đổi tên thiết bị (chỉ phụ huynh sở hữu hồ sơ)', {
        tag: 'Devices', parameters: childId,
        requestBody: jsonBody(objectSchema({name: field('string', {minLength: 1, maxLength: 80})})),
      }),
      delete: operation('Xóa thiết bị (chỉ phụ huynh sở hữu hồ sơ)', {
        tag: 'Devices', success: 204, parameters: childId,
      }),
    },
    '/children/{id}/agreements': {
      get: operation('Liệt kê thỏa thuận của hồ sơ trẻ', {tag: 'Agreements', parameters: childId}),
      post: operation('Tạo thỏa thuận', {
        tag: 'Agreements', success: 201, parameters: childId,
        requestBody: jsonBody(objectSchema({
          title: field('string', {minLength: 3, maxLength: 200}),
          reward: field('integer', {minimum: 1, maximum: 120}),
        })),
      }),
    },
    '/agreements/{id}': {
      patch: operation('Phê duyệt hoặc từ chối thỏa thuận (chỉ phụ huynh)', {
        tag: 'Agreements', parameters: childId,
        requestBody: jsonBody(objectSchema({status: field('string', {enum: ['approved', 'rejected']})})),
      }),
      delete: operation('Xóa thỏa thuận (chỉ phụ huynh)', {tag: 'Agreements', success: 204, parameters: childId}),
    },
    '/children/{id}/nfc': {
      put: operation('Gắn thẻ NFC bằng SHA-256 hash (chỉ phụ huynh)', {
        tag: 'Check-ins', parameters: childId,
        requestBody: jsonBody(objectSchema({
          tagHash: field('string', {pattern: '^[a-f0-9]{64}$'}),
        })),
      }),
    },
    '/children/{id}/nfc-schedule': {
      put: operation('Cấu hình khung giờ nhận thưởng NFC theo giờ Việt Nam', {
        tag: 'Check-ins', parameters: childId,
        requestBody: jsonBody(objectSchema({
          startTime: field('string', {pattern: '^(?:[01]\\d|2[0-3]):[0-5]\\d$'}),
          endTime: field('string', {pattern: '^(?:[01]\\d|2[0-3]):[0-5]\\d$'}),
        })),
      }),
    },
    '/children/{id}/checkins': {
      get: operation('Liệt kê tối đa 50 lần check-in gần nhất', {tag: 'Check-ins', parameters: childId}),
      post: operation('Check-in bằng thẻ NFC; lần đầu mỗi ngày được thưởng 30 phút', {
        tag: 'Check-ins', success: 201, parameters: childId,
        requestBody: jsonBody(objectSchema({
          tagHash: field('string', {pattern: '^[a-f0-9]{64}$'}),
        })),
      }),
    },
    '/children/{id}/location': {
      get: operation('Lấy vị trí được chia sẻ cho hồ sơ trẻ', {tag: 'Location', parameters: childId}),
      put: operation('Chia sẻ/cập nhật vị trí (chỉ tài khoản trẻ đã liên kết)', {
        tag: 'Location', parameters: childId,
        requestBody: jsonBody({'$ref': '#/components/schemas/LocationInput'}),
      }),
      delete: operation('Xóa vị trí đã chia sẻ (chỉ tài khoản trẻ đã liên kết)', {
        tag: 'Location', success: 204, parameters: childId,
      }),
    },
    '/staff/dashboard': {
      get: operation('Lấy thống kê tổng hợp (staff/admin)', {tag: 'Administration'}),
    },
    '/admin/users': {
      get: operation('Liệt kê tối đa 200 tài khoản (admin)', {tag: 'Administration'}),
    },
    '/admin/users/{id}/role': {
      patch: operation('Đổi vai trò tài khoản (admin)', {
        tag: 'Administration', parameters: childId,
        requestBody: jsonBody(objectSchema({role: field('string', {enum: ['parent', 'child', 'staff']})})),
      }),
    },
  },
};
