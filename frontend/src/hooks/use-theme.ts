import { useEffect, useState } from 'react';

export function useTheme() {
  const [theme, setTheme] = useState(
    document.documentElement.getAttribute('data-theme') || 'dark'
  );

  useEffect(() => {
    const observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        if (mutation.type === 'attributes' && mutation.attributeName === 'data-theme') {
          const newTheme = document.documentElement.getAttribute('data-theme') || 'dark';
          setTheme(newTheme);
        }
      }
    });

    observer.observe(document.documentElement, {
      attributes: true,
    });

    return () => {
      observer.disconnect();
    };
  }, []);

  return theme as 'light' | 'dark';
}
