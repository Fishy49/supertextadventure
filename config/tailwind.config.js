module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}'
  ],
  theme: {
    extend: {
      listStyleType: {
        square: 'square',
      },
      fontSize: {
        xs: ['1rem', { lineHeight: '1rem' }],
        sm: ['1.3rem', { lineHeight: '1.25rem' }],
        base: ['1.6rem', { lineHeight: '1.8rem' }],
        lg: ['1.8rem', { lineHeight: '1.9rem' }],
        xl: ['2rem', { lineHeight: '1.75rem' }],
        '2xl': ['2.25rem', { lineHeight: '2rem' }],
        '3xl': ['2.875rem', { lineHeight: '2.25rem' }],
        '4xl': ['3rem', { lineHeight: '2.5rem' }],
        '5xl': ['3.25rem', { lineHeight: '1' }],
        '6xl': ['3.75rem', { lineHeight: '1' }],
        '7xl': ['4.5rem', { lineHeight: '1' }],
        '8xl': ['6rem', { lineHeight: '1' }],
        '9xl': ['8rem', { lineHeight: '1' }],
      },
      keyframes: {
        blink: {
          'to': { opacity: '0.7' },
        }
      },
      animation: {
        blink: 'blink 1s steps(5, start) infinite',
      },
      colors: {
        'terminal-green': '#8fe86b',
      },
    },
  },
  variants: {
    extend: {
      padding: ['last']
    }
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/aspect-ratio'),
    require('@tailwindcss/typography'),
  ]
}
