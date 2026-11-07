package chat

import "context"

type ProgressFunc func(stage, label string)
type progressKey struct{}

func WithProgress(ctx context.Context, fn ProgressFunc) context.Context {
	return context.WithValue(ctx, progressKey{}, fn)
}

func ReportProgress(ctx context.Context, stage, label string) {
	if fn, ok := ctx.Value(progressKey{}).(ProgressFunc); ok && fn != nil {
		fn(stage, label)
	}
}
