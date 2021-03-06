import { Record, Map } from 'immutable'

const remoteCallObject = {
  loading: false,
  http: null,
  data: null,
  message: null,
  error: false,
  action: null,
}

const RemoteCallRecord = Record(remoteCallObject)

class RemoteCall extends RemoteCallRecord {
  // Extend immutable js Record
  isLoading(action) {
    return this.loading && this.action === action
  }
}

export function parseErrorResponse(object) {
  const { data } = object.response
  const remoteCallData = data.data ? Map(data.data.errors) : Map()

  return new RemoteCall({
    loading: false,
    http: object.response,
    data: Map({ errors: remoteCallData }),
    message: data.message,
    error: object.response.status >= 400,
  })
}

export default RemoteCall
