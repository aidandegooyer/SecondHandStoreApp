from django.shortcuts import render
from django.http import JsonResponse
from django.core import serializers
from django.db.models import Q
from PIL import Image
import mlSubsystem.sender as sender
from django.middleware.csrf import get_token
from .forms import ImageUploadForm, ProductUploadForm
from .models import InventoryItem
from django.views.decorators.csrf import csrf_exempt
import logging
import json
from django.core.files.storage import default_storage


itemNumberOn = 1  # Tracks the next item number for the database

# Configure logging
logger = logging.getLogger(__name__)

@csrf_exempt
def upload_image(request):
    if request.method == 'POST':
        image = request.FILES.get('image')

        if image:
            try:
                logger.info(f"Received image: {image.name}")

                # Directly save the file without opening it with PIL
                file_path = default_storage.save('images/' + image.name, image)

                logger.info(f"Image saved at: {file_path}")
                return JsonResponse({'status': 'success', 'file_path': file_path}, status=200)

            except Exception as e:
                logger.error(f"Error saving the image: {e}")
                return JsonResponse({'error': str(e)}, status=500)
        else:
            logger.error("No image provided in the request.")
            return JsonResponse({'error': 'No image provided'}, status=400)

    logger.error("Invalid method for image upload.")
    return JsonResponse({'error': 'Invalid method'}, status=405)


@csrf_exempt
def create_listing(request):
    if request.method == 'POST':
        name = request.POST.get('name')
        description = request.POST.get('description')
        price = request.POST.get('price')
        image = request.FILES.get('image')  # This is the uploaded image file

        if image:
            # Save the image and create a listing object
            # For example, save the image to your model
            listing = InventoryItem.objects.create(
                name=name,
                description=description,
                price=price,
                image=image
            )
            return JsonResponse({'status': 'success', 'id': listing.id}, status=201)
        else:
            return JsonResponse({'error': 'Image not provided'}, status=400)
    return JsonResponse({'error': 'Invalid method'}, status=405)


def get_next(request):
    items_to_send = int(request.GET.get('itemsToSend', 0))  # Default to 0 if not provided
    id_to_start = int(request.GET.get('idToStart', 0))      # Default to 0 if not provided
    search_term = request.GET.get('searchTerm', "")         # Default to empty string if not provided

    all_items = InventoryItem.objects.filter(archieved=False)

    if search_term:
        all_items = all_items.filter(
            Q(name__icontains=search_term) | Q(description__icontains=search_term)
        )
    to_return = all_items[id_to_start:id_to_start + items_to_send]

    items_list = [
        {"id": item.id, "name": item.name, "description": item.description, "price": item.price}
        for item in to_return
    ]
    total_count = all_items.count()

    return JsonResponse({'items': items_list, 'total_count': total_count})


@csrf_exempt
def edit_listing(request, itemNumber):
    if request.method == 'PUT':
        try:
            data = json.loads(request.body)
            name = data.get('name')
            description = data.get('description')
            price = data.get('price')

            item = InventoryItem.objects.get(id=itemNumber)
            item.name = name
            item.description = description
            item.price = float(price)
            item.archieved = False
            item.save()

            return JsonResponse({'message': 'Listing updated successfully'})
        except InventoryItem.DoesNotExist:
            return JsonResponse({'error': 'Item not found'}, status=404)
        except Exception as e:
            logger.error(f"Error updating listing: {e}")
            return JsonResponse({'error': 'An unexpected error occurred'}, status=500)

    return JsonResponse({'error': 'Invalid HTTP method. Only PUT is allowed.'}, status=405)


@csrf_exempt
def delete_listing(request, itemNumber):
    if request.method == 'DELETE':
        try:
            item = InventoryItem.objects.get(id=itemNumber)
            item.archieved = True
            item.save()
            return JsonResponse({'message': 'Listing archived successfully'})
        except InventoryItem.DoesNotExist:
            return JsonResponse({'error': 'Item not found'}, status=404)

    return JsonResponse({'error': 'Invalid HTTP method. Only DELETE is allowed.'}, status=405)


def get_csrf_token(request):
    return JsonResponse({'csrfToken': get_token(request)})
