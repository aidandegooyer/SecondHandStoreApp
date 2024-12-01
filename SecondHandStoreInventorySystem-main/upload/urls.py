from django.urls import path
from . import views

urlpatterns = [ 
    path('uploadImage/', views.upload_image, name='upload_image'),
    path('createListing/', views.create_listing, name='create_listing'),
    path('getNext/', views.get_next, name='get_next'),  # Moved parameters to query string
    path('editListing/<int:itemNumber>/', views.edit_listing, name='edit_listing'),  # Keep only the identifier in the path
    path('deleteListing/<int:itemNumber>/', views.delete_listing, name='delete_listing'),
    path('get-csrf-token/', views.get_csrf_token, name='get_csrf_token'),
]
